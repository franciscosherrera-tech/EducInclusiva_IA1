-- =====================================================================
-- 1) Varios dispositivos por usuario (tabla device_tokens)
-- 2) Alertas para la psicopedagoga cuando un alumno consulta muchas veces
--    a la IA sobre el mismo material.
--
-- Requiere: public.is_psico() (perfiles_accesibilidad.sql),
--           material_activity (actividad_y_permisos.sql) y
--           la extensión pg_net (notificaciones_trigger.sql).
-- ANTES de ejecutar: reemplazá TU_SECRETO por el mismo valor de WEBHOOK_SECRET.
-- No subas este archivo a git con el secreto escrito.
-- Ejecutar una sola vez en Supabase → SQL Editor.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) device_tokens: un usuario puede tener varios teléfonos
-- ---------------------------------------------------------------------
create table if not exists public.device_tokens (
  token      text primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_user_idx
  on public.device_tokens (user_id);

-- Sin políticas: la app solo entra por las dos funciones de abajo y el
-- servidor lee con la clave de servicio.
alter table public.device_tokens enable row level security;

-- Pasa los tokens que ya estaban guardados en profiles
insert into public.device_tokens (token, user_id)
select fcm_token, id from public.profiles where fcm_token is not null
on conflict (token) do nothing;

-- Si el teléfono lo usa otra cuenta, el token pasa a ser de la nueva
create or replace function public.register_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or coalesce(p_token, '') = '' then return; end if;
  insert into public.device_tokens (token, user_id)
  values (p_token, auth.uid())
  on conflict (token)
  do update set user_id = auth.uid(), updated_at = now();
end;
$$;

create or replace function public.unregister_device_token(p_token text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.device_tokens
  where token = p_token and user_id = auth.uid();
$$;

revoke execute on function public.register_device_token(text) from public, anon;
revoke execute on function public.unregister_device_token(text) from public, anon;
grant execute on function public.register_device_token(text) to authenticated;
grant execute on function public.unregister_device_token(text) to authenticated;

-- ---------------------------------------------------------------------
-- 2) Alertas de ayuda
-- ---------------------------------------------------------------------
create table if not exists public.help_alerts (
  id          uuid primary key default gen_random_uuid(),
  student_id  uuid not null references auth.users(id) on delete cascade,
  material_id uuid not null references public.study_materials(id) on delete cascade,
  subject_id  uuid references public.subjects(id) on delete cascade,
  ask_count   int  not null,
  created_at  timestamptz not null default now(),
  resolved_at timestamptz
);

create index if not exists help_alerts_open_idx
  on public.help_alerts (created_at desc) where resolved_at is null;

alter table public.help_alerts enable row level security;

drop policy if exists "help_alerts_select_psico" on public.help_alerts;
create policy "help_alerts_select_psico"
on public.help_alerts for select to authenticated
using (public.is_psico());

-- La psico puede marcarlas como atendidas
drop policy if exists "help_alerts_update_psico" on public.help_alerts;
create policy "help_alerts_update_psico"
on public.help_alerts for update to authenticated
using (public.is_psico())
with check (public.is_psico());

-- Cada consulta a la IA sobre un material cuenta. Al llegar al umbral dentro
-- de la ventana de días se crea UNA alerta y se avisa por push.
create or replace function public.check_help_alert()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_threshold constant int := 3;   -- consultas necesarias para alertar
  v_days      constant int := 7;   -- ventana de tiempo
  v_count     int;
  v_alert     public.help_alerts;
begin
  if new.action <> 'ask_ai' then return new; end if;

  select count(*) into v_count
  from public.material_activity
  where student_id = new.student_id
    and material_id = new.material_id
    and action = 'ask_ai'
    and created_at > now() - make_interval(days => v_days);

  if v_count >= v_threshold and not exists (
    select 1 from public.help_alerts
    where student_id = new.student_id
      and material_id = new.material_id
      and created_at > now() - make_interval(days => v_days)
  ) then
    insert into public.help_alerts (student_id, material_id, subject_id, ask_count)
    values (new.student_id, new.material_id, new.subject_id, v_count)
    returning * into v_alert;

    perform net.http_post(
      url     := 'https://xxprfhxttlkmobcmpcop.supabase.co/functions/v1/notify-new-material',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-webhook-secret', 'TU_SECRETO'
      ),
      body    := jsonb_build_object(
        'type', 'INSERT',
        'table', 'help_alerts',
        'record', to_jsonb(v_alert)
      )
    );
  end if;

  return new;
exception when others then
  -- Un problema con las alertas nunca debe impedir registrar la actividad
  raise warning 'check_help_alert falló: %', sqlerrm;
  return new;
end;
$$;

drop trigger if exists on_activity_check_help on public.material_activity;
create trigger on_activity_check_help
after insert on public.material_activity
for each row execute function public.check_help_alert();
