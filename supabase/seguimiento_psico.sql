-- =====================================================================
-- Seguimiento: la psicopedagoga puede LEER chats, mensajes y materiales
-- de todos los alumnos (solo lectura). Requiere public.is_psico(),
-- creada en perfiles_accesibilidad.sql.
-- Ejecutar una sola vez en Supabase → SQL Editor.
-- =====================================================================

drop policy if exists "chats_select_psico" on public.chats;
create policy "chats_select_psico"
on public.chats for select to authenticated
using (public.is_psico());

drop policy if exists "messages_select_psico" on public.messages;
create policy "messages_select_psico"
on public.messages for select to authenticated
using (public.is_psico());

drop policy if exists "study_materials_select_psico" on public.study_materials;
create policy "study_materials_select_psico"
on public.study_materials for select to authenticated
using (public.is_psico());
