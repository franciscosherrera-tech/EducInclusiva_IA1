-- =====================================================================
-- Perfiles de accesibilidad por alumno + curso asignado por la psico
-- Ejecutar una sola vez en Supabase → SQL Editor.
-- =====================================================================

-- 1) Columnas nuevas en student_settings
alter table public.student_settings
  add column if not exists adhd            boolean not null default false,
  add column if not exists dyslexia        boolean not null default false,
  add column if not exists dysgraphia      boolean not null default false,
  add column if not exists dysorthography  boolean not null default false,
  add column if not exists dyscalculia     boolean not null default false,
  add column if not exists color_blindness text    not null default 'none';

alter table public.student_settings
  drop constraint if exists student_settings_color_blindness_check;
alter table public.student_settings
  add constraint student_settings_color_blindness_check
  check (color_blindness in (
    'none', 'deuteranomaly', 'protanomaly', 'deuteranopia', 'protanopia',
    'tritanomaly', 'tritanopia', 'achromatopsia'
  ));

-- 2) Función auxiliar: ¿el usuario actual es psicopedagoga?
--    (security definer evita la recursión de RLS al leer profiles)
create or replace function public.is_psico()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and lower(role) = 'psicopedagoga'
  );
$$;

-- 3) RLS de student_settings
alter table public.student_settings enable row level security;

drop policy if exists "settings_select_own_or_psico" on public.student_settings;
create policy "settings_select_own_or_psico"
on public.student_settings for select to authenticated
using (student_id = (select auth.uid()) or public.is_psico());

drop policy if exists "settings_insert_psico" on public.student_settings;
create policy "settings_insert_psico"
on public.student_settings for insert to authenticated
with check (public.is_psico());

drop policy if exists "settings_update_psico" on public.student_settings;
create policy "settings_update_psico"
on public.student_settings for update to authenticated
using (public.is_psico())
with check (public.is_psico());

-- 4) La psico puede ver todos los perfiles y asignar año/división
drop policy if exists "profiles_select_psico" on public.profiles;
create policy "profiles_select_psico"
on public.profiles for select to authenticated
using (public.is_psico());

drop policy if exists "profiles_update_psico" on public.profiles;
create policy "profiles_update_psico"
on public.profiles for update to authenticated
using (public.is_psico())
with check (public.is_psico());

-- 5) El alumno no puede cambiarse el curso: solo la psico modifica year/division
create or replace function public.protect_student_course()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (new.year is distinct from old.year
      or new.division is distinct from old.division)
     and auth.uid() is not null   -- permite editar desde el panel de Supabase
     and not public.is_psico() then
    new.year := old.year;
    new.division := old.division;
  end if;
  return new;
end;
$$;

drop trigger if exists protect_student_course on public.profiles;
create trigger protect_student_course
before update on public.profiles
for each row execute function public.protect_student_course();
