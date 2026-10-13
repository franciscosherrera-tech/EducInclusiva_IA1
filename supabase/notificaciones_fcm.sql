-- =====================================================================
-- Notificaciones push (FCM): columna para guardar el token del teléfono.
-- Ejecutar una sola vez en Supabase → SQL Editor.
-- =====================================================================

alter table public.profiles
  add column if not exists fcm_token text;

-- El servidor busca alumnos por curso y con token: este índice lo acelera
create index if not exists profiles_push_idx
  on public.profiles (year, division)
  where fcm_token is not null;

-- Nota: cada usuario ya puede actualizar SU fila de profiles (la app guarda
-- el token con update ... where id = auth.uid()). No hace falta otra política.
-- La Edge Function lee los tokens con la clave de servicio (service role),
-- que se salta las reglas de acceso.
