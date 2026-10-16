// Edge Function de notificaciones push. La dispara la base de datos:
//  - INSERT en study_materials → avisa a los alumnos del curso.
//  - INSERT en help_alerts     → avisa a la psicopedagoga (alumno con dudas).
// Secretos necesarios (supabase secrets set ...):
//   FIREBASE_SERVICE_ACCOUNT  → contenido completo del JSON de la cuenta de servicio
// SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY ya los entrega Supabase.

import { createClient } from "npm:@supabase/supabase-js@2";

// La clave se guarda en base64 (FIREBASE_SERVICE_ACCOUNT_B64) porque PowerShell
// rompe las comillas del JSON al pasarlo como argumento. Se lee recién al
// recibir una llamada, para que un error de configuración se vea en los logs.
// deno-lint-ignore no-explicit-any
let serviceAccount: any = {};

function loadServiceAccount() {
  const b64 = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_B64");
  if (b64) {
    const json = new TextDecoder().decode(
      Uint8Array.from(atob(b64.trim()), (c) => c.charCodeAt(0)),
    );
    return JSON.parse(json);
  }
  return JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "{}");
}

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// ---------------------------------------------------------------------------
// Token de acceso de Google (OAuth2) a partir de la cuenta de servicio
// ---------------------------------------------------------------------------
const b64url = (data: ArrayBuffer | string) => {
  const bytes = typeof data === "string"
    ? new TextEncoder().encode(data)
    : new Uint8Array(data);
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
};

async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));

  const pem = (serviceAccount.private_key as string)
    .replace(/-----(BEGIN|END) PRIVATE KEY-----/g, "")
    .replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(`${header}.${claims}`),
  );

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${b64url(signature)}`,
    }),
  });
  if (!res.ok) throw new Error(`OAuth falló: ${await res.text()}`);
  return (await res.json()).access_token;
}

// ---------------------------------------------------------------------------
// Envío a un token con la API HTTP v1 de FCM
// ---------------------------------------------------------------------------
async function sendPush(
  accessToken: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<"ok" | "invalid" | "error"> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
          android: { priority: "HIGH" },
        },
      }),
    },
  );
  if (res.ok) return "ok";
  // 404 UNREGISTERED / 400 INVALID_ARGUMENT: el token ya no sirve
  if (res.status === 404 || res.status === 400) return "invalid";
  console.error("FCM error", res.status, await res.text());
  return "error";
}

// ---------------------------------------------------------------------------
// Destinatarios y envío
// ---------------------------------------------------------------------------

/** Tokens de todos los teléfonos de esos usuarios (sin repetidos). */
async function tokensOf(userIds: string[]): Promise<string[]> {
  if (!userIds.length) return [];
  const [devices, legacy] = await Promise.all([
    supabase.from("device_tokens").select("token").in("user_id", userIds),
    // Columna anterior (un solo teléfono por usuario); se mantiene mientras haya apps viejas
    supabase.from("profiles").select("fcm_token").in("id", userIds).not("fcm_token", "is", null),
  ]);
  const all = [
    ...(devices.data ?? []).map((d: { token: string }) => d.token),
    ...(legacy.data ?? []).map((p: { fcm_token: string }) => p.fcm_token),
  ];
  return [...new Set(all)];
}

async function broadcast(
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string>,
) {
  if (!tokens.length) return { sent: 0, invalid: 0 };
  const accessToken = await getAccessToken();

  let sent = 0;
  const invalid: string[] = [];
  for (const t of tokens) {
    const result = await sendPush(accessToken, t, title, body, data);
    if (result === "ok") sent++;
    if (result === "invalid") invalid.push(t);
  }

  // Limpiar tokens que ya no existen (app desinstalada)
  if (invalid.length) {
    await supabase.from("device_tokens").delete().in("token", invalid);
    await supabase.from("profiles").update({ fcm_token: null }).in("fcm_token", invalid);
  }
  return { sent, invalid: invalid.length };
}

// ---------------------------------------------------------------------------
// Casos
// ---------------------------------------------------------------------------
// deno-lint-ignore no-explicit-any
async function onNewMaterial(material: any) {
  const { data: subject } = await supabase
    .from("subjects")
    .select("name, year, division")
    .eq("id", material.subject_id)
    .single();
  if (!subject) return { skipped: "materia no encontrada" };

  const { data: students } = await supabase
    .from("profiles")
    .select("id")
    .ilike("role", "estudiante")
    .eq("year", subject.year)
    .eq("division", subject.division);

  const tokens = await tokensOf((students ?? []).map((s: { id: string }) => s.id));
  return await broadcast(
    tokens,
    `Nuevo en ${subject.name}`,
    material.title ?? "Tu docente subió un contenido nuevo",
    {
      type: "new_material",
      material_id: String(material.id),
      subject_id: String(material.subject_id),
    },
  );
}

// deno-lint-ignore no-explicit-any
async function onHelpAlert(alert: any) {
  const [student, material, subject, psicos] = await Promise.all([
    supabase.from("profiles").select("name").eq("id", alert.student_id).single(),
    supabase.from("study_materials").select("title").eq("id", alert.material_id).single(),
    alert.subject_id
      ? supabase.from("subjects").select("name").eq("id", alert.subject_id).single()
      : Promise.resolve({ data: null }),
    supabase.from("profiles").select("id").ilike("role", "psicopedagoga"),
  ]);

  const who = student.data?.name ?? "Un alumno";
  const what = material.data?.title ?? "un material";
  const where = subject.data?.name ? ` (${subject.data.name})` : "";

  const tokens = await tokensOf((psicos.data ?? []).map((p: { id: string }) => p.id));
  return await broadcast(
    tokens,
    `Posible dificultad: ${who}`,
    `Consultó ${alert.ask_count} veces «${what}»${where} esta semana`,
    { type: "help_alert", student_id: String(alert.student_id) },
  );
}

// ---------------------------------------------------------------------------
// Handler del webhook
// ---------------------------------------------------------------------------
Deno.serve(async (req) => {
  // Solo el disparador de la base de datos conoce este secreto
  const secret = Deno.env.get("WEBHOOK_SECRET");
  if (!secret || req.headers.get("x-webhook-secret") !== secret) {
    return new Response("no autorizado", { status: 401 });
  }

  try {
    serviceAccount = loadServiceAccount();
    if (!serviceAccount.client_email || !serviceAccount.private_key) {
      throw new Error("La clave de Firebase no está bien guardada (faltan client_email o private_key)");
    }
    const payload = await req.json();
    if (payload.type !== "INSERT") return new Response("ignorado", { status: 200 });

    let result;
    if (payload.table === "study_materials") {
      result = await onNewMaterial(payload.record);
    } else if (payload.table === "help_alerts") {
      result = await onHelpAlert(payload.record);
    } else {
      return new Response("ignorado", { status: 200 });
    }

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error(e);
    return new Response(String(e), { status: 500 });
  }
});
