-- =====================================================================
-- Mimo · esquema de base de datos para Supabase
-- Ejecuta este archivo entero en Supabase → SQL Editor → New query → Run.
--
-- Inicio de sesión: solo Google y Apple (OAuth). No hay contraseñas.
-- Los datos de acceso (email, proveedor, fecha de alta, último acceso)
-- los guarda Supabase en auth.users; aquí guardamos el resto.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Perfil del jugador
-- ---------------------------------------------------------------------
create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  display_name  text not null default 'Jugador'
                check (char_length(display_name) between 1 and 16),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  last_seen_at  timestamptz,
  settings      jsonb not null default '{}'::jsonb
                constraint profiles_settings_check
                check (jsonb_typeof(settings) = 'object' and pg_column_size(settings) < 4000)
);

-- ---------------------------------------------------------------------
-- Historial: un registro por usuario y día (el día va de 3:00 a 3:00)
--   am / md / pm : cepillados de mañana, mediodía y noche
--   glasses      : array con la hora (ms) de cada vaso de agua
--   extra        : resto de hábitos del día (pasos, lectura, cama, cocina, baño…)
-- ---------------------------------------------------------------------
create table public.day_logs (
  user_id     uuid not null references auth.users(id) on delete cascade,
  day         date not null,
  am          boolean not null default false,
  md          boolean not null default false,
  pm          boolean not null default false,
  glasses     jsonb   not null default '[]'::jsonb
              check (jsonb_typeof(glasses) = 'array' and jsonb_array_length(glasses) <= 16),
  extra       jsonb   not null default '{}'::jsonb
              constraint day_logs_extra_check
              check (jsonb_typeof(extra) = 'object' and pg_column_size(extra) < 4000),
  updated_at  timestamptz not null default now(),
  primary key (user_id, day)
);

-- ---------------------------------------------------------------------
-- Jefes semanales derrotados (week_start = lunes de esa semana)
-- ---------------------------------------------------------------------
create table public.boss_wins (
  user_id      uuid not null references auth.users(id) on delete cascade,
  week_start   date not null,
  defeated_at  timestamptz not null default now(),
  primary key (user_id, week_start)
);

-- ---------------------------------------------------------------------
-- Progreso: resumen calculado por la app a partir del historial.
-- Es lo que ven los demás miembros de tus grupos en el ranking.
-- ---------------------------------------------------------------------
create table public.progress (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  xp            int      not null default 0   check (xp >= 0),
  level         int      not null default 1   check (level >= 1),
  stage         smallint not null default 0   check (stage between 0 and 5),
  energy        smallint not null default 100 check (energy between 0 and 100),
  streak        int      not null default 0   check (streak >= 0),
  best_streak   int      not null default 0   check (best_streak >= 0),
  perfect_days  int      not null default 0   check (perfect_days >= 0),
  bosses        int      not null default 0   check (bosses >= 0),
  week_start    date,
  week_xp       int      not null default 0   check (week_xp >= 0),
  updated_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- Grupos de amigos para el ranking (se entra con un código de 6 letras)
-- ---------------------------------------------------------------------
create table public.groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 1 and 30),
  code        text not null unique,
  owner_id    uuid not null references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now()
);

create table public.group_members (
  group_id   uuid not null references public.groups(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  joined_at  timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index group_members_user_idx on public.group_members(user_id);

-- =====================================================================
-- Funciones auxiliares (security definer para evitar recursión en RLS)
-- =====================================================================
create or replace function public.is_member(g uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from group_members where group_id = g and user_id = auth.uid());
$$;

create or replace function public.shares_group(other uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from group_members a
    join group_members b on b.group_id = a.group_id
    where a.user_id = auth.uid() and b.user_id = other
  );
$$;

-- Al registrarse alguien: crea su perfil (con su nombre de pila) y su progreso
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    left(coalesce(nullif(split_part(coalesce(
      new.raw_user_meta_data->>'full_name',
      new.raw_user_meta_data->>'name', ''), ' ', 1), ''), 'Jugador'), 16)
  )
  on conflict (id) do nothing;
  insert into public.progress (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- =====================================================================
-- Seguridad por filas (RLS): cada uno solo toca lo suyo
-- =====================================================================
alter table public.profiles      enable row level security;
alter table public.day_logs      enable row level security;
alter table public.boss_wins     enable row level security;
alter table public.progress      enable row level security;
alter table public.groups        enable row level security;
alter table public.group_members enable row level security;

-- Perfil: ves el tuyo y el de quien comparte grupo contigo; solo editas el tuyo
create policy "profiles_select" on public.profiles for select to authenticated
  using (id = auth.uid() or public.shares_group(id));
create policy "profiles_insert" on public.profiles for insert to authenticated
  with check (id = auth.uid());
create policy "profiles_update" on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Historial y jefes: privados, solo los tuyos
create policy "day_logs_own" on public.day_logs for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "boss_wins_own" on public.boss_wins for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Progreso: lo ven tus compañeros de grupo; solo lo editas tú
create policy "progress_select" on public.progress for select to authenticated
  using (user_id = auth.uid() or public.shares_group(user_id));
create policy "progress_insert" on public.progress for insert to authenticated
  with check (user_id = auth.uid());
create policy "progress_update" on public.progress for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Grupos: ves los tuyos; el creador puede renombrarlo o borrarlo.
-- Crear y unirse se hace con las funciones create_group / join_group.
create policy "groups_select" on public.groups for select to authenticated
  using (owner_id = auth.uid() or public.is_member(id));
create policy "groups_update" on public.groups for update to authenticated
  using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "groups_delete" on public.groups for delete to authenticated
  using (owner_id = auth.uid());

-- Miembros: ves los de tus grupos; puedes salir tú o te puede echar el creador
create policy "members_select" on public.group_members for select to authenticated
  using (public.is_member(group_id));
create policy "members_delete" on public.group_members for delete to authenticated
  using (
    user_id = auth.uid()
    or exists (select 1 from public.groups g where g.id = group_id and g.owner_id = auth.uid())
  );

-- =====================================================================
-- Funciones que llama la app
-- =====================================================================

-- Crear un grupo: devuelve el grupo con su código para compartir
create or replace function public.create_group(group_name text)
returns public.groups language plpgsql security definer set search_path = public as $$
declare
  g public.groups;
  new_code text;
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if auth.uid() is null then raise exception 'Necesitas iniciar sesión'; end if;
  if (select count(*) from groups where owner_id = auth.uid()) >= 10 then
    raise exception 'Has llegado al máximo de 10 grupos creados';
  end if;
  loop
    new_code := '';
    for i in 1..6 loop
      new_code := new_code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from groups where code = new_code);
  end loop;
  insert into groups (name, code, owner_id)
  values (left(trim(group_name), 30), new_code, auth.uid())
  returning * into g;
  insert into group_members (group_id, user_id) values (g.id, auth.uid());
  return g;
end;
$$;

-- Unirse a un grupo con su código
create or replace function public.join_group(group_code text)
returns public.groups language plpgsql security definer set search_path = public as $$
declare g public.groups;
begin
  if auth.uid() is null then raise exception 'Necesitas iniciar sesión'; end if;
  select * into g from groups where code = upper(trim(group_code));
  if not found then raise exception 'Código no válido'; end if;
  if (select count(*) from group_members where group_id = g.id) >= 50 then
    raise exception 'El grupo está lleno';
  end if;
  insert into group_members (group_id, user_id) values (g.id, auth.uid())
  on conflict do nothing;
  return g;
end;
$$;

-- Ranking de un grupo: XP de esta semana, racha y etapa de Mimo de cada miembro
create or replace function public.group_ranking(g uuid)
returns table (user_id uuid, display_name text, stage smallint, week_xp int, streak int, xp int)
language sql stable security definer set search_path = public as $$
  select
    p.id,
    p.display_name,
    coalesce(pr.stage, 0::smallint),
    case
      when pr.week_start = date_trunc('week', (now() at time zone 'Europe/Madrid') - interval '3 hours')::date
      then pr.week_xp else 0
    end,
    coalesce(pr.streak, 0),
    coalesce(pr.xp, 0)
  from group_members m
  join profiles p        on p.id = m.user_id
  left join progress pr  on pr.user_id = m.user_id
  where m.group_id = g and public.is_member(g)
  order by 4 desc, 6 desc;
$$;

-- Borrar la cuenta y todos sus datos
create or replace function public.delete_my_account()
returns void language sql security definer set search_path = public, auth as $$
  delete from auth.users where id = auth.uid();
$$;

-- Solo los usuarios con sesión pueden llamar a las funciones
revoke execute on function public.is_member(uuid)         from public, anon;
revoke execute on function public.shares_group(uuid)      from public, anon;
revoke execute on function public.create_group(text)      from public, anon;
revoke execute on function public.join_group(text)        from public, anon;
revoke execute on function public.group_ranking(uuid)     from public, anon;
revoke execute on function public.delete_my_account()     from public, anon;
revoke execute on function public.handle_new_user()       from public, anon, authenticated;
grant  execute on function public.is_member(uuid)         to authenticated;
grant  execute on function public.shares_group(uuid)      to authenticated;
grant  execute on function public.create_group(text)      to authenticated;
grant  execute on function public.join_group(text)        to authenticated;
grant  execute on function public.group_ranking(uuid)     to authenticated;
grant  execute on function public.delete_my_account()     to authenticated;
