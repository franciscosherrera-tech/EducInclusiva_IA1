# Guía: sacar la clave de Gemini de la app

**Objetivo:** que la clave de Gemini viva en el servidor (Supabase) y no dentro de la app
ni del repositorio.

```
Antes:    App (con la clave) ────────────────► Gemini
Después:  App ──► función gemini-proxy ──────► Gemini
                  (la clave es un secreto de Supabase)
```

La app ya está lista: llama primero a la función `gemini-proxy` y, **mientras la función no
esté desplegada**, usa la clave guardada en el código como respaldo. Por eso el tutor no se
cae en ningún momento del proceso.

## Paso 1. Crear una clave nueva

1. Entrá a https://aistudio.google.com → **Get API key** → **Create API key**.
2. Copiala. **No la pegues en el código, en el chat ni en un archivo del proyecto.**

## Paso 2. Guardarla como secreto en Supabase

En PowerShell (la clave no lleva comillas ni espacios, así que no hay problema):

```powershell
cd C:\Users\Alumno\Documents\eduinclusiva_ia
npx supabase secrets set GEMINI_API_KEY=TU_CLAVE_NUEVA --project-ref xxprfhxttlkmobcmpcop
```

## Paso 3. Desplegar la función

**Sin** `--no-verify-jwt`: así solo la pueden usar usuarios que iniciaron sesión.

```powershell
npx supabase functions deploy gemini-proxy --project-ref xxprfhxttlkmobcmpcop
```

## Paso 4. Probar el tutor

1. Instalá el APK nuevo (se genera con `flutter build apk --release --no-tree-shake-icons`).
2. Iniciá sesión con un alumno y hacele una pregunta al tutor.
3. Probá también **"Preguntar al Tutor IA" sobre un PDF**, de tamaño normal y uno grande.
4. En Supabase → **Edge Functions → gemini-proxy → Logs** tienen que aparecer las llamadas.
   Si ves llamadas ahí, el tutor está usando la función y no la clave vieja.

## Paso 5. Revocar la clave vieja y limpiar el código

Solo cuando el paso 4 anduvo bien:

1. En AI Studio, **borrá la clave vieja**. Desde ese momento deja de servir, aunque alguien
   la haya copiado del historial de GitHub.
2. Pedile a Claude que saque la clave y el respaldo de `gemini_service.dart`.
3. Probá el tutor una vez más.

## Si algo falla

| Síntoma | Causa probable |
| --- | --- |
| El tutor responde "Error de configuración... Código: 403" | La clave nueva no es válida o no se guardó bien (repetí el paso 2) |
| No aparecen llamadas en los logs de `gemini-proxy` | La función no está desplegada o el alumno no tiene sesión iniciada |
| Funciona con texto pero falla con un PDF grande | La función tiene un límite de tamaño o de tiempo. Avisá para ajustarlo |
| `401` en los logs | La sesión del alumno venció: cerrar sesión y volver a entrar |
