-- =====================================================================
-- Mimo · migración 004: notificaciones push
-- Ejecuta este archivo en Supabase → SQL Editor → New query → Run.
-- Es seguro ejecutarlo más de una vez.
--
-- La programación del envío (cada 15 minutos) va aparte, en
-- supabase/functions/notify/cron.sql, porque lleva un secreto que no
-- debe estar en el repositorio.
-- =====================================================================

-- Móviles en los que cada jugador ha activado los avisos
create table if not exists public.push_subscriptions (
  endpoint    text primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  p256dh      text not null,
  auth        text not null,
  created_at  timestamptz not null default now()
);
create index if not exists push_subscriptions_user_idx on public.push_subscriptions(user_id);

alter table public.push_subscriptions enable row level security;
drop policy if exists "push_own" on public.push_subscriptions;
create policy "push_own" on public.push_subscriptions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Avisos ya enviados, para no repetir el mismo aviso el mismo día.
-- Solo la usa la función del servidor (sin políticas: la app no la ve).
create table if not exists public.notification_log (
  user_id  uuid not null references auth.users(id) on delete cascade,
  day      date not null,
  kind     text not null,
  sent_at  timestamptz not null default now(),
  primary key (user_id, day, kind)
);
alter table public.notification_log enable row level security;

-- Extensiones para lanzar la función cada 15 minutos
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
