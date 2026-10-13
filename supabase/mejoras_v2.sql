-- =====================================================================
-- Mejoras v2: notas de la psicopedagoga, materias asignadas por la psico
-- y avisos en vivo de contenido nuevo.
-- Requiere public.is_psico() (perfiles_accesibilidad.sql).
-- Ejecutar una sola vez en Supabase → SQL Editor.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Notas de la psicopedagoga sobre cada alumno (privadas: solo psico)
-- ---------------------------------------------------------------------
create table if not exists public.student_notes (
  id         uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.profiles(id) on delete cascade,
  author_id  uuid not null default auth.uid() references auth.users(id),
  body       text not null check (length(trim(body)) > 0),
  created_at timestamptz not null default now()
);

create index if not exists student_notes_student_idx
  on public.student_notes (student_id, created_at desc);

alter table public.student_notes enable row level security;

drop policy if exists "notes_select_psico" on public.student_notes;
create policy "notes_select_psico"
on public.student_notes for select to authenticated
using (public.is_psico());

drop policy if exists "notes_insert_psico" on public.student_notes;
create policy "notes_insert_psico"
on public.student_notes for insert to authenticated
with check (public.is_psico() and author_id = (select auth.uid()));

drop policy if exists "notes_delete_own_psico" on public.student_notes;
create policy "notes_delete_own_psico"
on public.student_notes for delete to authenticated
using (public.is_psico() and author_id = (select auth.uid()));

-- ---------------------------------------------------------------------
-- 2) La psico puede crear, reasignar y borrar materias de cualquier docente
-- ---------------------------------------------------------------------
drop policy if exists "subjects_insert_psico" on public.subjects;
create policy "subjects_insert_psico"
on public.subjects for insert to authenticated
with check (public.is_psico());

drop policy if exists "subjects_update_psico" on public.subjects;
create policy "subjects_update_psico"
on public.subjects for update to authenticated
using (public.is_psico())
with check (public.is_psico());

drop policy if exists "subjects_delete_psico" on public.subjects;
create policy "subjects_delete_psico"
on public.subjects for delete to authenticated
using (public.is_psico());

-- ---------------------------------------------------------------------
-- 3) Avisos en vivo: la app se entera cuando un docente sube contenido
-- ---------------------------------------------------------------------
do $$
begin
  alter publication supabase_realtime add table public.study_materials;
exception
  when duplicate_object then null;  -- ya estaba agregada
end $$;
