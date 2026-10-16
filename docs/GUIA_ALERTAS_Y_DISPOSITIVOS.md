# Guía: alertas para la psicopedagoga y varios dispositivos

## Qué hace

- **Varios dispositivos:** una misma cuenta puede recibir notificaciones en más de un teléfono
  (tabla `device_tokens`).
- **Alertas de ayuda:** si un alumno le pregunta **3 o más veces** a la IA sobre el **mismo material**
  en **7 días**, se crea una alerta y la psicopedagoga recibe una notificación. Las alertas
  se ven en la pestaña **Alertas** de su panel, donde puede marcarlas como atendidas.

Los números (3 consultas y 7 días) se cambian en `v_threshold` y `v_days`, dentro de la
función `check_help_alert()` de `supabase/alertas_y_dispositivos.sql`.

## Pasos (en este orden)

1. **Ejecutar el SQL.** Abrí `supabase/alertas_y_dispositivos.sql`, reemplazá `TU_SECRETO` por el
   valor de `WEBHOOK_SECRET` (el mismo del trigger de materiales) y ejecutalo en Supabase →
   SQL Editor. **No subas el archivo a git con el secreto escrito.**
2. **Desplegar la función** (ahora también atiende las alertas):

   ```powershell
   cd C:\Users\Alumno\Documents\eduinclusiva_ia
   npx supabase functions deploy notify-new-material --project-ref xxprfhxttlkmobcmpcop --no-verify-jwt
   ```

3. **Instalar el APK nuevo.**

## Cómo probar

- **Alertas:** con un alumno, tocá 3 veces "Preguntar al Tutor IA" sobre el mismo material. La
  psicopedagoga tiene que recibir la notificación y ver la alerta en la pestaña **Alertas**.
- **Varios dispositivos:** iniciá sesión con el mismo alumno en dos teléfonos y subí un material
  desde la cuenta del docente. Tienen que sonar los dos.

## Si algo falla

| Síntoma | Causa probable |
| --- | --- |
| La pestaña Alertas dice "No se pudieron cargar" | Falta ejecutar el SQL (paso 1) |
| Se crea la alerta pero no llega la notificación | El secreto del SQL no coincide con `WEBHOOK_SECRET`, o falta desplegar la función. Mirá los logs de `notify-new-material` |
| Los materiales nuevos dejan de avisar | Revisá los logs de la función: puede ser un error de despliegue |
