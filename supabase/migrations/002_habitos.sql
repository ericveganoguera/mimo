-- =====================================================================
-- Mimo · migración 002: nuevos hábitos y ajustes por jugador
-- Ejecuta este archivo en Supabase → SQL Editor → New query → Run.
-- Es seguro ejecutarlo más de una vez.
-- =====================================================================

-- Hábitos del día que no tienen columna propia:
--   h (hábitos activos ese día), steps, sg (objetivo de pasos), read,
--   readStart, bed, kitchen, bath
alter table public.day_logs
  add column if not exists extra jsonb not null default '{}'::jsonb;

-- Ajustes del jugador: hábitos activados y objetivo de pasos
alter table public.profiles
  add column if not exists settings jsonb not null default '{}'::jsonb;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'day_logs_extra_check') then
    alter table public.day_logs add constraint day_logs_extra_check
      check (jsonb_typeof(extra) = 'object' and pg_column_size(extra) < 4000);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_settings_check') then
    alter table public.profiles add constraint profiles_settings_check
      check (jsonb_typeof(settings) = 'object' and pg_column_size(settings) < 4000);
  end if;
end $$;
