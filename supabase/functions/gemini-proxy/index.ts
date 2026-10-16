// Edge Function: intermediario entre la app y Gemini.
//
// La clave de Gemini vive acá como secreto (GEMINI_API_KEY) y nunca viaja en la
// app. La app manda el mismo cuerpo que le mandaría a Gemini y esta función lo
// reenvía tal cual, devolviendo la respuesta de Gemini sin cambios.
//
// Seguridad: se despliega CON verificación de JWT (el valor por defecto), así que
// solo la pueden usar usuarios que hayan iniciado sesión en la app.
//
// Secreto necesario:  npx supabase secrets set GEMINI_API_KEY=tu_clave_nueva

const GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models";

// Sirve para que la app distinga una respuesta de esta función de un error
// genérico de Supabase (por ejemplo, "función no encontrada").
const PROXY_HEADER = { "x-proxy": "gemini" };

const json = (body: unknown, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...PROXY_HEADER },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "método no permitido" }, 405);

  // Solo modelos de Gemini: evita usar la función para otra cosa
  const model = new URL(req.url).searchParams.get("model") ?? "";
  if (!/^gemini-[a-z0-9.\-]+$/.test(model)) {
    return json({ error: "modelo inválido" }, 400);
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) return json({ error: "falta GEMINI_API_KEY en los secretos" }, 500);

  try {
    const res = await fetch(`${GEMINI_URL}/${model}:generateContent`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "x-goog-api-key": apiKey },
      body: await req.text(),
    });

    return new Response(await res.text(), {
      status: res.status,
      headers: { "Content-Type": "application/json", ...PROXY_HEADER },
    });
  } catch (e) {
    console.error(e);
    return json({ error: "no se pudo conectar con Gemini" }, 502);
  }
});
