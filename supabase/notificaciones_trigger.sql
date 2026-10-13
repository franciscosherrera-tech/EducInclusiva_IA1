-- =====================================================================
-- Disparador: al insertar un contenido, llama a la Edge Function
-- "notify-new-material" (que envía las notificaciones push).
--
-- ANTES de ejecutar: reemplazá TU_SECRETO por el mismo valor que guardaste con
--   npx supabase secrets set WEBHOOK_SECRET=TU_SECRETO --project-ref ...
-- No subas este archivo a git con el secreto escrito.
-- =====================================================================

create extension if not exists pg_net with schema extensions;

create or replace function public.notify_new_material()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  perform net.http_post(
    url     := 'https://xxprfhxttlkmobcmpcop.supabase.co/functions/v1/notify-new-material',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', 'TU_SECRETO'
    ),
    body    := jsonb_build_object(
      'type', 'INSERT',
      'table', 'study_materials',
      'record', to_jsonb(new)
    )
  );
  return new;
exception when others then
  -- Un problema con las notificaciones nunca debe impedir subir el contenido
  raise warning 'notify_new_material falló: %', sqlerrm;
  return new;
end;
$$;

drop trigger if exists on_new_material_notify on public.study_materials;
create trigger on_new_material_notify
after insert on public.study_materials
for each row execute function public.notify_new_material();
