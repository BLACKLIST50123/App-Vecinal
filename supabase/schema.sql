-- =====================================================================
-- App Vecinal (AlphaCoders) — Esquema Supabase
-- Ejecutar completo en: Supabase > SQL Editor > New query > Run
-- Es idempotente: se puede volver a ejecutar sin romper nada.
-- =====================================================================
-- Roles (decisiones D1–D5):
--   visitante    : sin cuenta. Lee todo. En emergencia puede pedir ayuda.
--   vecino       : cuenta verificada por GPS. Publica favores, servicios
--                  (perfil prestador opcional) y da "Visto Bueno".
--   organizacion : grupo de apoyo verificado. Publica grupos/recursos y
--                  atiende reportes de emergencia.
--   moderador    : junta vecinal. Activa/desactiva el modo emergencia.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Zona de la app: Chimbote / Nuevo Chimbote (centro + radio en km)
-- ---------------------------------------------------------------------
create or replace function public.en_zona(p_lat double precision, p_lng double precision)
returns boolean language sql immutable as $$
  select p_lat is not null and p_lng is not null and
    sqrt( power((p_lat - (-9.0950)) * 111.32, 2) +
          power((p_lng - (-78.5600)) * 111.32 * cos(radians(-9.0950)), 2) ) <= 15;
$$;

-- ---------------------------------------------------------------------
-- PERFILES
-- ---------------------------------------------------------------------
create table if not exists public.perfiles (
  id             uuid primary key references auth.users(id) on delete cascade,
  nombre         text not null,
  telefono       text,
  rol            text not null default 'vecino'
                 check (rol in ('vecino','organizacion','moderador')),
  sector         text,
  lat            double precision,
  lng            double precision,
  verificado_gps boolean not null default false,
  es_prestador   boolean not null default false,
  oficio         text,
  created_at     timestamptz not null default now()
);

create or replace function public.mi_rol() returns text
language sql stable security definer set search_path = public as $$
  select coalesce((select rol from public.perfiles where id = auth.uid()), 'visitante');
$$;

create or replace function public.mi_perfil() returns json
language sql stable security definer set search_path = public as $$
  select row_to_json(p) from public.perfiles p where p.id = auth.uid();
$$;

-- Crea el perfil al registrarse. La verificación GPS se calcula en el
-- servidor (D2): el cliente envía lat/lng y aquí se decide si está en zona.
create or replace function public.crear_perfil() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_lat double precision := nullif(new.raw_user_meta_data->>'lat','')::double precision;
  v_lng double precision := nullif(new.raw_user_meta_data->>'lng','')::double precision;
begin
  insert into public.perfiles (id, nombre, telefono, sector, lat, lng, verificado_gps)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'nombre',''), split_part(new.email,'@',1)),
    nullif(new.raw_user_meta_data->>'telefono',''),
    nullif(new.raw_user_meta_data->>'sector',''),
    v_lat, v_lng,
    public.en_zona(v_lat, v_lng)
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists al_crear_usuario on auth.users;
create trigger al_crear_usuario after insert on auth.users
  for each row execute function public.crear_perfil();

alter table public.perfiles enable row level security;
drop policy if exists perfiles_select on public.perfiles;
create policy perfiles_select on public.perfiles for select using (true);
drop policy if exists perfiles_update on public.perfiles;
create policy perfiles_update on public.perfiles for update
  using (id = auth.uid()) with check (id = auth.uid());

-- Privacidad: nadie lee teléfono ni coordenadas exactas de otros.
-- Nadie puede cambiarse el rol a sí mismo.
revoke all on public.perfiles from anon, authenticated;
grant select (id, nombre, rol, sector, verificado_gps, es_prestador, oficio)
  on public.perfiles to anon, authenticated;
grant update (nombre, telefono, sector, es_prestador, oficio)
  on public.perfiles to authenticated;
grant execute on function public.mi_perfil() to authenticated;

-- ---------------------------------------------------------------------
-- Autor: nombre y rol se copian del perfil en el servidor (no se pueden
-- falsificar desde la app). Publicaciones sin cuenta no tienen rol.
-- ---------------------------------------------------------------------
create or replace function public.poner_autor() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.autor_id is not null then
    select p.nombre, p.rol into new.autor_nombre, new.autor_rol
      from public.perfiles p where p.id = new.autor_id;
  elsif auth.role() in ('anon','authenticated') then
    new.autor_rol := null;
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------------
-- MÓDULO 1 · SERVICIOS DE PROXIMIDAD (día a día + grupos de apoyo)
-- ---------------------------------------------------------------------
create table if not exists public.servicios (
  id            uuid primary key default gen_random_uuid(),
  autor_id      uuid references public.perfiles(id) on delete cascade default auth.uid(),
  autor_nombre  text,
  autor_rol     text,
  categoria     text not null,
  titulo        text not null check (char_length(titulo) between 3 and 120),
  descripcion   text check (char_length(descripcion) <= 1000),
  precio_ref    text,
  telefono      text,
  horario       text,
  sector        text,
  lat           double precision,
  lng           double precision,
  es_emergencia boolean not null default false,   -- grupo / servicio de apoyo
  activo        boolean not null default true,
  created_at    timestamptz not null default now()
);
create index if not exists servicios_emergencia_idx on public.servicios (es_emergencia, activo);

drop trigger if exists servicios_autor on public.servicios;
create trigger servicios_autor before insert on public.servicios
  for each row execute function public.poner_autor();

alter table public.servicios enable row level security;
drop policy if exists servicios_select on public.servicios;
create policy servicios_select on public.servicios for select using (activo or autor_id = auth.uid());
drop policy if exists servicios_insert on public.servicios;
create policy servicios_insert on public.servicios for insert to authenticated
  with check (
    autor_id = auth.uid()
    and (not es_emergencia or public.mi_rol() in ('organizacion','moderador'))
  );
drop policy if exists servicios_update on public.servicios;
create policy servicios_update on public.servicios for update to authenticated
  using (autor_id = auth.uid() or public.mi_rol() = 'moderador');
drop policy if exists servicios_delete on public.servicios;
create policy servicios_delete on public.servicios for delete to authenticated
  using (autor_id = auth.uid() or public.mi_rol() = 'moderador');

-- "Visto Bueno Vecinal": un vecino, un visto bueno por servicio; no se
-- puede recomendar el servicio propio.
create table if not exists public.vistos_buenos (
  id           uuid primary key default gen_random_uuid(),
  servicio_id  uuid not null references public.servicios(id) on delete cascade,
  autor_id     uuid references public.perfiles(id) on delete cascade default auth.uid(),
  autor_nombre text,
  autor_rol    text,
  comentario   text check (char_length(comentario) <= 280),
  created_at   timestamptz not null default now(),
  unique (servicio_id, autor_id)
);

drop trigger if exists vistos_buenos_autor on public.vistos_buenos;
create trigger vistos_buenos_autor before insert on public.vistos_buenos
  for each row execute function public.poner_autor();

alter table public.vistos_buenos enable row level security;
drop policy if exists vb_select on public.vistos_buenos;
create policy vb_select on public.vistos_buenos for select using (true);
drop policy if exists vb_insert on public.vistos_buenos;
create policy vb_insert on public.vistos_buenos for insert to authenticated
  with check (
    autor_id = auth.uid()
    and not exists (select 1 from public.servicios s
                    where s.id = servicio_id and s.autor_id = auth.uid())
  );
drop policy if exists vb_delete on public.vistos_buenos;
create policy vb_delete on public.vistos_buenos for delete to authenticated
  using (autor_id = auth.uid());

-- ---------------------------------------------------------------------
-- ESTADO DE EMERGENCIA (una sola fila). Lo activa el moderador (D3).
-- ---------------------------------------------------------------------
create table if not exists public.emergencia (
  id             int primary key default 1 check (id = 1),
  activa         boolean not null default false,
  titulo         text,
  mensaje        text,
  activada_por   uuid references public.perfiles(id),
  actualizado_en timestamptz not null default now()
);
insert into public.emergencia (id) values (1) on conflict (id) do nothing;

alter table public.emergencia enable row level security;
drop policy if exists emergencia_select on public.emergencia;
create policy emergencia_select on public.emergencia for select using (true);
drop policy if exists emergencia_update on public.emergencia;
create policy emergencia_update on public.emergencia for update to authenticated
  using (public.mi_rol() = 'moderador') with check (public.mi_rol() = 'moderador');

-- ---------------------------------------------------------------------
-- MÓDULO 2 · CADENA DE FAVORES (día a día) + TABLERO HUMANITARIO
-- (emergencia). Sin dinero.
-- ---------------------------------------------------------------------
create table if not exists public.publicaciones (
  id                uuid primary key default gen_random_uuid(),
  autor_id          uuid references public.perfiles(id) on delete set null default auth.uid(),
  autor_nombre      text,
  autor_rol         text,
  tipo              text not null check (tipo in ('pido','ofrezco')),
  categoria         text not null,
  titulo            text not null check (char_length(titulo) between 3 and 140),
  descripcion       text check (char_length(descripcion) <= 1000),
  contacto_nombre   text,
  contacto_telefono text,
  personas          int check (personas is null or personas between 1 and 500),
  prioridad         text not null default 'normal' check (prioridad in ('normal','alta','critica')),
  es_emergencia     boolean not null default false,
  estado            text not null default 'abierta' check (estado in ('abierta','en_curso','resuelta')),
  atendido_por      uuid references public.perfiles(id),
  lat               double precision,
  lng               double precision,
  sector            text,
  origen            text not null default 'app' check (origen in ('app','qr','sin_cuenta')),
  creado_offline_en timestamptz,
  created_at        timestamptz not null default now()
);
create index if not exists publicaciones_modo_idx on public.publicaciones (es_emergencia, estado, created_at desc);

drop trigger if exists publicaciones_autor on public.publicaciones;
create trigger publicaciones_autor before insert on public.publicaciones
  for each row execute function public.poner_autor();

alter table public.publicaciones enable row level security;
drop policy if exists pub_select on public.publicaciones;
create policy pub_select on public.publicaciones for select using (true);

-- Vecino con cuenta: publica a su nombre, o sube pedidos que llegaron
-- por QR (mula de datos) / sin cuenta, sin quedar como autor.
drop policy if exists pub_insert_auth on public.publicaciones;
create policy pub_insert_auth on public.publicaciones for insert to authenticated
  with check (
    (autor_id = auth.uid() and origen = 'app')
    or (autor_id is null and origen in ('qr','sin_cuenta'))
  );

-- Sin cuenta (D5): solo pedidos de ayuda y solo con emergencia activa.
drop policy if exists pub_insert_anon on public.publicaciones;
create policy pub_insert_anon on public.publicaciones for insert to anon
  with check (
    autor_id is null and origen in ('qr','sin_cuenta')
    and es_emergencia and tipo = 'pido'
    and exists (select 1 from public.emergencia e where e.activa)
  );

-- Cambiar estado: el autor, una organización (D4) o el moderador.
drop policy if exists pub_update on public.publicaciones;
create policy pub_update on public.publicaciones for update to authenticated
  using (autor_id = auth.uid() or public.mi_rol() in ('organizacion','moderador'));
drop policy if exists pub_delete on public.publicaciones;
create policy pub_delete on public.publicaciones for delete to authenticated
  using (autor_id = auth.uid() or public.mi_rol() = 'moderador');

-- ---------------------------------------------------------------------
-- Para convertir una cuenta en moderador u organización (una vez):
--   update public.perfiles set rol = 'moderador'
--   where id = (select id from auth.users where email = 'correo@ejemplo.com');
-- ---------------------------------------------------------------------
