-- =====================================================================
-- Migración 0012 · Notificaciones push (llegan con la app cerrada)
-- 1. dispositivos: token de cada celular y qué avisos quiere recibir.
-- 2. registrar_dispositivo(): la app guarda su token (con o sin cuenta).
-- 3. config_push: URL de la Edge Function y clave secreta (se llena a mano).
-- 4. Disparadores: emergencia, SOS / pedidos, pedidos a servicios y foro
--    llaman a la Edge Function `enviar-avisos`, que envía los push.
-- Idempotente: es segura de ejecutar varias veces.
-- Requiere la extensión pg_net (Database > Extensions > pg_net).
-- =====================================================================

create extension if not exists pg_net with schema extensions;

-- ---------------------------------------------------------------------
-- 1. DISPOSITIVOS
-- ---------------------------------------------------------------------
create table if not exists public.dispositivos (
  token          text primary key,
  usuario_id     uuid references auth.users(id) on delete set null,
  plataforma     text not null default 'android',
  -- Preferencias (las mismas de Perfil > Notificaciones)
  emergencia     boolean not null default true,
  sos_cercano    boolean not null default true,
  pedidos_ayuda  boolean not null default true,
  mis_servicios  boolean not null default true,
  foro           boolean not null default false,
  -- Ubicación APROXIMADA (para SOS cercanos)
  sector         text,
  lat            double precision,
  lng            double precision,
  actualizado_en timestamptz not null default now()
);

create index if not exists dispositivos_usuario_idx on public.dispositivos (usuario_id);

-- Nadie lee ni escribe la tabla directo: solo la función de abajo y la
-- Edge Function (service role). Así un vecino no puede ver tokens ajenos.
alter table public.dispositivos enable row level security;

-- ---------------------------------------------------------------------
-- 2. REGISTRAR DISPOSITIVO (lo llama la app)
-- ---------------------------------------------------------------------
create or replace function public.registrar_dispositivo(
  p_token text,
  p_emergencia boolean,
  p_sos_cercano boolean,
  p_pedidos_ayuda boolean,
  p_mis_servicios boolean,
  p_foro boolean,
  p_sector text default null,
  p_lat double precision default null,
  p_lng double precision default null
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_token is null or char_length(p_token) < 20 then
    raise exception 'token inválido';
  end if;
  insert into public.dispositivos as d
    (token, usuario_id, emergencia, sos_cercano, pedidos_ayuda, mis_servicios, foro, sector, lat, lng, actualizado_en)
  values
    (p_token, auth.uid(), p_emergencia, p_sos_cercano, p_pedidos_ayuda, p_mis_servicios, p_foro, p_sector, p_lat, p_lng, now())
  on conflict (token) do update set
    usuario_id = auth.uid(),
    emergencia = excluded.emergencia,
    sos_cercano = excluded.sos_cercano,
    pedidos_ayuda = excluded.pedidos_ayuda,
    mis_servicios = excluded.mis_servicios,
    foro = excluded.foro,
    sector = excluded.sector,
    lat = excluded.lat,
    lng = excluded.lng,
    actualizado_en = now();
end $$;

grant execute on function public.registrar_dispositivo(text, boolean, boolean, boolean, boolean, boolean, text, double precision, double precision)
  to anon, authenticated;

-- ---------------------------------------------------------------------
-- 3. CONFIGURACIÓN (se llena UNA vez en el SQL Editor, no en Git)
--    insert into public.config_push (id, url, secreto) values
--      (1, 'https://<PROYECTO>.supabase.co/functions/v1/enviar-avisos', '<CLAVE_SECRETA>')
--    on conflict (id) do update set url = excluded.url, secreto = excluded.secreto;
-- ---------------------------------------------------------------------
create table if not exists public.config_push (
  id      int primary key default 1 check (id = 1),
  url     text not null,
  secreto text not null
);
alter table public.config_push enable row level security; -- sin políticas: solo el servidor

-- ---------------------------------------------------------------------
-- 4. DISPARADORES → Edge Function
-- ---------------------------------------------------------------------
create or replace function public.avisar_push() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  c public.config_push;
  v_tipo text;
begin
  select * into c from public.config_push where id = 1;
  if c is null then
    return new; -- push aún no configurado: no hace nada
  end if;

  if tg_table_name = 'emergencia' then
    if new.activa is not distinct from old.activa then return new; end if;
    v_tipo := 'emergencia';
  elsif tg_table_name = 'publicaciones' then
    if new.origen = 'sos' then v_tipo := 'sos';
    elsif new.tipo = 'pido' then v_tipo := 'pedido_ayuda';
    else return new; end if;
  elsif tg_table_name = 'pedidos_servicio' then
    v_tipo := 'pedido_servicio';
  elsif tg_table_name = 'foro_temas' then
    v_tipo := 'foro';
  else
    return new;
  end if;

  perform net.http_post(
    url := c.url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-webhook-secret', c.secreto),
    body := jsonb_build_object('tipo', v_tipo, 'registro', to_jsonb(new))
  );
  return new;
exception when others then
  return new; -- un fallo del push nunca debe impedir guardar el dato
end $$;

drop trigger if exists push_emergencia on public.emergencia;
create trigger push_emergencia after update on public.emergencia
  for each row execute function public.avisar_push();

drop trigger if exists push_publicaciones on public.publicaciones;
create trigger push_publicaciones after insert on public.publicaciones
  for each row execute function public.avisar_push();

drop trigger if exists push_pedidos_servicio on public.pedidos_servicio;
create trigger push_pedidos_servicio after insert on public.pedidos_servicio
  for each row execute function public.avisar_push();

drop trigger if exists push_foro_temas on public.foro_temas;
create trigger push_foro_temas after insert on public.foro_temas
  for each row execute function public.avisar_push();

-- ---------------------------------------------------------------------
-- 5. REGISTRO DE MIGRACIÓN
-- ---------------------------------------------------------------------
insert into public.migraciones (version, nombre)
values ('0012', 'notificaciones_push')
on conflict (version) do nothing;
