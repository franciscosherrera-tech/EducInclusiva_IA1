-- =====================================================================
-- 1) Actividad del alumno sobre los contenidos (descargas y consultas a la IA)
-- 2) Permisos claros de study_materials y del bucket "materials"
-- Requiere public.is_psico() (perfiles_accesibilidad.sql).
-- Ejecutar una sola vez en Supabase → SQL Editor.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Tabla de actividad
-- ---------------------------------------------------------------------
create table if not exists public.material_activity (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid not null default auth.uid() references auth.users(id) on delete cascade,
  material_id uuid not null references public.study_materials(id) on delete cascade,
  subject_id  uuid references public.subjects(id) on delete cascade,
  action      text not null check (action in ('download', 'ask_ai')),
  created_at  timestamptz not null default now()
);

create index if not exists material_activity_student_idx
  on public.material_activity (student_id, created_at desc);

alter table public.material_activity enable row level security;

drop policy if exists "activity_insert_own" on public.material_activity;
create policy "activity_insert_own"
on public.material_activity for insert to authenticated
with check (student_id = (select auth.uid()));

drop policy if exists "activity_select_own_or_psico" on public.material_activity;
create policy "activity_select_own_or_psico"
on public.material_activity for select to authenticated
using (student_id = (select auth.uid()) or public.is_psico());

-- ---------------------------------------------------------------------
-- 2) study_materials: borra las políticas viejas y deja reglas claras
-- ---------------------------------------------------------------------
do $$
declare p record;
begin
  for p in select policyname from pg_policies
           where schemaname = 'public' and tablename = 'study_materials'
  loop
    execute format('drop policy %I on public.study_materials', p.policyname);
  end loop;
end $$;

alter table public.study_materials enable row level security;
alter table public.study_materials alter column uploaded_by set default auth.uid();

-- Todos los usuarios logueados ven los materiales (alumnos, docentes y psico)
create policy "materials_select_authenticated"
on public.study_materials for select to authenticated
using (true);

-- Solo docentes o psicopedagogas publican, siempre a su nombre
create policy "materials_insert_teacher"
on public.study_materials for insert to authenticated
with check (
  uploaded_by = (select auth.uid())
  and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and lower(p.role) in ('docente', 'psicopedagoga')
  )
);

-- Solo quien lo subió puede editarlo o borrarlo
create policy "materials_update_own"
on public.study_materials for update to authenticated
using (uploaded_by = (select auth.uid()))
with check (uploaded_by = (select auth.uid()));

create policy "materials_delete_own"
on public.study_materials for delete to authenticated
using (uploaded_by = (select auth.uid()));

-- ---------------------------------------------------------------------
-- 3) Storage: bucket "materials" público para leer, restringido para escribir
-- ---------------------------------------------------------------------
update storage.buckets set public = true where id = 'materials';

do $$
declare p record;
begin
  for p in select policyname from pg_policies
           where schemaname = 'storage' and tablename = 'objects'
             and (coalesce(qual, '') like '%materials%'
                  or coalesce(with_check, '') like '%materials%')
  loop
    execute format('drop policy %I on storage.objects', p.policyname);
  end loop;
end $$;

create policy "materials_files_read"
on storage.objects for select
using (bucket_id = 'materials');

create policy "materials_files_upload"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'materials'
  and exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and lower(p.role) in ('docente', 'psicopedagoga')
  )
);

create policy "materials_files_delete_own"
on storage.objects for delete to authenticated
using (bucket_id = 'materials' and owner = (select auth.uid()));
