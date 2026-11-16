-- =====================================================================
-- Mimo · ejecutar la función "notify" cada 15 minutos
-- Sustituye los dos valores <...> antes de ejecutarlo en el SQL Editor.
-- NO subas este archivo con los valores reales al repositorio.
--   <ANON_KEY>     clave pública anon (la misma que hay en config.js)
--   <CRON_SECRET>  el mismo valor que el secreto CRON_SECRET de la función
-- =====================================================================

select cron.unschedule('mimo-notificaciones')
where exists (select 1 from cron.job where jobname = 'mimo-notificaciones');

select cron.schedule(
  'mimo-notificaciones',
  '*/15 * * * *',
  $$
  select net.http_post(
    url     := 'https://vinwwwwdsqkgwyjqiaag.supabase.co/functions/v1/notify',
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer <ANON_KEY>',
      'x-cron-secret', '<CRON_SECRET>'
    ),
    body    := '{}'::jsonb
  );
  $$
);
