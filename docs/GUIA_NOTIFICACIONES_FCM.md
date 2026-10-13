# Guía: notificaciones push (FCM + Supabase)

**Qué hace:** cuando un docente sube un contenido, los alumnos de ese curso reciben
una notificación en el celular, aunque la app esté cerrada.

```
Docente sube contenido
  → INSERT en study_materials
  → Database Webhook de Supabase
  → Edge Function "notify-new-material"
  → busca alumnos del curso con fcm_token
  → API HTTP v1 de Firebase (FCM)
  → notificación en el celular del alumno
```

**El código de la app ya está hecho.** Solo faltan los pasos de configuración
de abajo, que necesitan tu cuenta de Google y de Supabase. Hasta que los hagas,
la app funciona normal, sin notificaciones.

| Archivo | Para qué sirve |
| --- | --- |
| `lib/services/push_service.dart` | Inicia Firebase, pide el permiso y escucha los mensajes |
| `lib/main.dart` | Llama a `PushService.instance.init()` al arrancar |
| `lib/providers/user_provider.dart` | Guarda el token en `profiles.fcm_token` (`syncPushToken`) y lo borra al cerrar sesión |
| `android/.../AndroidManifest.xml` | Permiso `POST_NOTIFICATIONS` (Android 13+) |
| `supabase/notificaciones_fcm.sql` | Agrega la columna `fcm_token` |
| `supabase/functions/notify-new-material/index.ts` | La Edge Function que envía las notificaciones |

---

## Paso 1. Crear el proyecto en Firebase

1. Entrá a https://console.firebase.google.com con tu cuenta de Google.
2. **Agregar proyecto** → ponele un nombre (ej. `eduinclusiva-ia`). Podés desactivar Google Analytics.
3. No hace falta agregar la app Android a mano: lo hace el comando del paso 2.

## Paso 2. Vincular Flutter con `flutterfire configure`

Abrí una terminal en la carpeta del proyecto (necesitás Node.js, que ya tenés).

```powershell
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```

Si `flutterfire` no se reconoce, agregá al PATH de Windows la carpeta
`%LOCALAPPDATA%\Pub\Cache\bin` y abrí una terminal nueva.

En el asistente:
- Elegí el proyecto que creaste.
- Marcá solo **android** (no iOS por ahora).
- Confirmá el identificador `com.example.eduinclusiva_ia`.

Esto crea `android/app/google-services.json`, genera `lib/firebase_options.dart` y
agrega el plugin de Google Services a los archivos de Gradle. Nuestro código usa
`Firebase.initializeApp()` sin opciones, que toma la configuración de
`google-services.json`; `firebase_options.dart` no se usa y podés ignorarlo.

> Si después de `flutterfire configure` Gradle se queja de que falta el plugin
> `com.google.gms.google-services`, agregalo así:
> - `android/settings.gradle.kts`, dentro de `plugins { }`:
>   `id("com.google.gms.google-services") version "4.4.2" apply false`
> - `android/app/build.gradle.kts`, dentro de `plugins { }`:
>   `id("com.google.gms.google-services")`

Dependencias (ya agregadas a `pubspec.yaml`):

```yaml
firebase_core: ^4.15.0
firebase_messaging: ^16.7.0
```

## Paso 3. Código de Flutter (ya incluido)

**`lib/main.dart`**: inicia las notificaciones después de Supabase:

```dart
await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.anonKey);
await PushService.instance.init();   // Firebase + permiso + handlers
```

**`lib/services/push_service.dart`**: contiene el handler de segundo plano. Debe ser una
función de nivel superior con `@pragma('vm:entry-point')` para que Android pueda llamarla
con la app cerrada:

```dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
```

`init()` hace tres cosas: `Firebase.initializeApp()`, `requestPermission()` (en Android 13+
aparece el cuadro "¿Permitir notificaciones?") y registra el handler. Si Firebase no está
configurado, captura el error y la app sigue funcionando.

Con la app abierta, FCM **no** muestra la notificación del sistema. No hace falta: el
aviso de contenido nuevo del inicio ya se actualiza solo (Supabase Realtime).

## Paso 4. Guardar el token en Supabase

1. En el **SQL Editor** de Supabase ejecutá `supabase/notificaciones_fcm.sql`:

```sql
alter table public.profiles add column if not exists fcm_token text;
```

2. El token se guarda desde `UserProvider`:

```dart
Future<void> syncPushToken() async {
  final token = await PushService.instance.getToken();
  if (token != null) await _saveFcmToken(token);   // update profiles set fcm_token
}
```

Se llama al final de `loadFromSupabase()` (cada vez que se carga el perfil al iniciar
sesión) y también cuando FCM renueva el token (`onTokenRefresh`). Al cerrar sesión,
`signOut()` pone `fcm_token = null` para que ese teléfono deje de recibir avisos de la
cuenta anterior.

**Limitación conocida:** hay un solo token por usuario. Si un alumno usa dos teléfonos,
solo recibe avisos en el último donde inició sesión. Si lo necesitan, se resuelve con
una tabla aparte `device_tokens`.

## Paso 5. Clave para enviar (cuenta de servicio)

1. Firebase Console → ⚙ **Configuración del proyecto** → pestaña **Cuentas de servicio**.
2. **Generar nueva clave privada** → se descarga un `.json`.
3. **No lo subas a git ni lo compartas.** Guardalo fuera del proyecto o con un nombre
   que contenga `service-account` (el `.gitignore` ya lo ignora).

## Paso 6. Desplegar la Edge Function

Necesitás la CLI de Supabase (con `npx` no hace falta instalarla). Desde la carpeta del proyecto:

```powershell
npx supabase login
npx supabase link --project-ref TU_PROJECT_REF
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes("C:/ruta/service-account.json"))
npx supabase secrets set FIREBASE_SERVICE_ACCOUNT_B64=$b64
npx supabase functions deploy notify-new-material
```

`TU_PROJECT_REF` es el código de tu URL de Supabase
(`https://TU_PROJECT_REF.supabase.co`). `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` los
entrega Supabase automáticamente a la función.

## Paso 7. El disparador (trigger de la base de datos)

En las versiones nuevas de Supabase el menú "Database → Webhooks" ya no existe, así
que el disparador se crea con SQL. Pasos:

1. Elegí un secreto (una cadena larga al azar) y guardalo en Supabase:

```powershell
npx supabase secrets set WEBHOOK_SECRET=TU_SECRETO --project-ref xxprfhxttlkmobcmpcop
```

2. Volvé a desplegar la función (ahora exige ese secreto) y desactivá la verificación
   de JWT, porque la autenticación la hace el secreto:

```powershell
cd C:\Users\Alumno\Documents\eduinclusiva_ia
npx supabase functions deploy notify-new-material --no-verify-jwt --project-ref xxprfhxttlkmobcmpcop
```

3. En el SQL Editor ejecutá `supabase/notificaciones_trigger.sql`, **reemplazando
   `TU_SECRETO` por el mismo valor**. Crea un trigger que, al insertar en
   `study_materials`, llama a la función. Si algo falla en las notificaciones, el
   contenido se sube igual.

## Paso 8. Probar

1. Instalá el APK nuevo en el teléfono del alumno, iniciá sesión y aceptá el permiso de notificaciones.
2. En la tabla `profiles`, verificá que el alumno tenga `fcm_token` y que su `year`/`division` coincidan con los de la materia.
3. Cerrá la app del alumno (deslizala fuera de recientes).
4. Con la cuenta del docente, subí un contenido a una materia de ese curso.
5. Al alumno le llega "Nuevo en *Materia*" con el título del contenido.

Si no llega, revisá en este orden:
- **Edge Functions → notify-new-material → Logs** en Supabase: ahí aparece el error.
- Que `fcm_token` no esté vacío (si está vacío: faltó el paso 2 o aceptar el permiso).
- Que el alumno tenga el mismo año y división que la materia.
- Que el webhook esté activo (**Database → Webhooks**).
- En el celular: Ajustes → Aplicaciones → la app → Notificaciones permitidas.

## Seguridad

- La clave de la cuenta de servicio solo vive como *secret* de Supabase, nunca en la app.
- Si las reglas de `profiles` permiten que cualquier usuario logueado lea los perfiles de otros, también podría ver la columna `fcm_token`. Un token por sí solo no permite enviar notificaciones (hace falta la cuenta de servicio), así que el riesgo es bajo.
