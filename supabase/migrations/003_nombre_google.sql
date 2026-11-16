-- =====================================================================
-- Mimo · migración 003: el nombre del jugador es el de su cuenta de Google
-- (nombre y apellidos) y no se puede cambiar desde la app.
-- Ejecuta este archivo en Supabase → SQL Editor → New query → Run.
-- Es seguro ejecutarlo más de una vez.
-- =====================================================================

-- Nombre completo a partir de los datos del proveedor (Google / Apple)
create or replace function public.provider_name(meta jsonb)
returns text language sql immutable as $$
  select left(coalesce(nullif(trim(coalesce(meta->>'full_name', meta->>'name', '')), ''), 'Jugador'), 80);
$$;

-- Permitir nombres completos (antes el máximo era 16 caracteres)
alter table public.profiles drop constraint if exists profiles_display_name_check;
alter table public.profiles add constraint profiles_display_name_check
  check (char_length(display_name) between 1 and 80);

-- Al registrarse: perfil con el nombre completo
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, public.provider_name(new.raw_user_meta_data))
  on conflict (id) do nothing;
  insert into public.progress (user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end;
$$;

-- Si cambia el nombre en Google, se actualiza al volver a iniciar sesión
create or replace function public.handle_user_updated()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.profiles
     set display_name = public.provider_name(new.raw_user_meta_data)
   where id = new.id
     and display_name is distinct from public.provider_name(new.raw_user_meta_data);
  return new;
end;
$$;

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
  after update of raw_user_meta_data on auth.users
  for each row execute function public.handle_user_updated();

-- Poner el nombre completo a los jugadores que ya existen
update public.profiles p
   set display_name = public.provider_name(u.raw_user_meta_data)
  from auth.users u
 where u.id = p.id
   and p.display_name is distinct from public.provider_name(u.raw_user_meta_data);

-- La app ya no puede cambiar el nombre: solo ajustes y fechas
revoke insert, update on public.profiles from anon, authenticated;
grant update (settings, updated_at, last_seen_at) on public.profiles to authenticated;

revoke execute on function public.handle_user_updated() from public, anon, authenticated;
