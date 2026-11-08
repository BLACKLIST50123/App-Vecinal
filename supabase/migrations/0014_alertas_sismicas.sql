-- =====================================================================
-- Migración 0014 · Alertas sísmicas y Modo Emergencia geolocalizado
-- 1. Amplía `emergencia` para soportar epicentro y radio de impacto.
-- 2. Crea tabla `sismos` para almacenar eventos sísmicos procesados.
-- 3. Agrega preferencia `sismos` a la tabla `dispositivos`.
-- 4. Función SQL `distancia_km` para cálculos geográficos en Postgres.
-- 5. Disparador para sismos que conecta con la Edge Function `enviar-avisos`.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. EXTENDER TABLA EMERGENCIA (Soporte para epicentro y radio)
-- ---------------------------------------------------------------------
alter table public.emergencia
  add column if not exists lat double precision,
  add column if not exists lng double precision,
  add column if not exists radio_km double precision,
  add column if not exists origen text default 'manual', -- 'manual' (moderador) o 'sismo' (automático)
  add column if not exists sismo_id text;

-- ---------------------------------------------------------------------
-- 2. TABLA DE SISMOS (Historial de sismos detectados y procesados)
-- ---------------------------------------------------------------------
create table if not exists public.sismos (
  id               text primary key, -- ID único (ej. de IGP o USGS)
  fecha_hora       timestamptz not null,
  magnitud         double precision not null,
  profundidad_km   double precision not null,
  ubicacion        text not null, -- ej. "17 km al O de Nuevo Chimbote"
  lat              double precision not null,
  lng              double precision not null,
  intensidad       text, -- ej. "III Nuevo Chimbote"
  radio_alerta_km  double precision not null,
  activo_emergencia boolean not null default false,
  notificado       boolean not null default false,
  creado_en        timestamptz not null default now()
);

create index if not exists sismos_fecha_idx on public.sismos (fecha_hora desc);

alter table public.sismos enable row level security;
drop policy if exists sismos_select on public.sismos;
create policy sismos_select on public.sismos for select using (true);

-- ---------------------------------------------------------------------
-- 3. DISPOSITIVOS: PREFERENCIA DE ALERTAS SÍSMICAS
-- ---------------------------------------------------------------------
alter table public.dispositivos
  add column if not exists sismos boolean not null default true;

-- Actualizamos registrar_dispositivo para admitir p_sismos
create or replace function public.registrar_dispositivo(
  p_token text,
  p_emergencia boolean,
  p_sos_cercano boolean,
  p_pedidos_ayuda boolean,
  p_mis_servicios boolean,
  p_foro boolean,
  p_sector text default null,
  p_lat double precision default null,
  p_lng double precision default null,
  p_sismos boolean default true
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_token is null or char_length(p_token) < 20 then
    raise exception 'token inválido';
  end if;
  insert into public.dispositivos as d
    (token, usuario_id, emergencia, sos_cercano, pedidos_ayuda, mis_servicios, foro, sismos, sector, lat, lng, actualizado_en)
  values
    (p_token, auth.uid(), p_emergencia, p_sos_cercano, p_pedidos_ayuda, p_mis_servicios, p_foro, p_sismos, p_sector, p_lat, p_lng, now())
  on conflict (token) do update set
    usuario_id     = auth.uid(),
    emergencia     = excluded.emergencia,
    sos_cercano    = excluded.sos_cercano,
    pedidos_ayuda  = excluded.pedidos_ayuda,
    mis_servicios  = excluded.mis_servicios,
    foro           = excluded.foro,
    sismos         = excluded.sismos,
    sector         = coalesce(excluded.sector, d.sector),
    lat            = coalesce(excluded.lat, d.lat),
    lng            = coalesce(excluded.lng, d.lng),
    actualizado_en = now();
end;
$$;

-- ---------------------------------------------------------------------
-- 4. FUNCIÓN AUXILIAR: DISTANCIA HAVERSINE EN SQL
-- ---------------------------------------------------------------------
create or replace function public.distancia_km(
  lat1 double precision,
  lng1 double precision,
  lat2 double precision,
  lng2 double precision
) returns double precision language sql immutable as $$
  select 6371 * 2 * asin(
    sqrt(
      power(sin(radians(lat2 - lat1) / 2), 2) +
      cos(radians(lat1)) * cos(radians(lat2)) *
      power(sin(radians(lng2 - lng1) / 2), 2)
    )
  );
$$;

-- ---------------------------------------------------------------------
-- 5. DISPARADOR DE SISMOS → Edge Function avisar_push
-- ---------------------------------------------------------------------
-- Actualizamos avisar_push para reconocer la tabla 'sismos'
create or replace function public.avisar_push() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare
  c public.config_push;
  v_tipo text;
begin
  select * into c from public.config_push where id = 1;
  if c is null then
    return new; -- push aún no configurado
  end if;

  if tg_table_name = 'emergencia' then
    if new.activa is not distinct from old.activa then return new; end if;
    v_tipo := 'emergencia';
  elsif tg_table_name = 'sismos' then
    v_tipo := 'sismo';
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
  return new; -- un fallo del push nunca impide guardar el dato
end $$;

drop trigger if exists push_sismos on public.sismos;
create trigger push_sismos after insert on public.sismos
  for each row execute function public.avisar_push();

-- ---------------------------------------------------------------------
-- 6. DISPARADOR: AUTO-ACTIVAR MODO EMERGENCIA SI ES SISMO FUERTE (>= 4.5)
-- ---------------------------------------------------------------------
create or replace function public.auto_activar_emergencia_sismo() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- Si el sismo es >= 4.5 o viene marcado como activo_emergencia, activa el modo emergencia geolocalizado
  if new.magnitud >= 4.5 or new.activo_emergencia then
    update public.emergencia
    set activa = true,
        titulo = '🚨 Sismo M ' || new.magnitud || ' - ' || new.ubicacion,
        mensaje = 'Sismo sentido en la zona. Mantén la calma, evacúa a zonas seguras y reporta si tienes daños o necesitas auxilio.',
        lat = new.lat,
        lng = new.lng,
        radio_km = new.radio_alerta_km,
        origen = 'sismo',
        sismo_id = new.id,
        actualizado_en = now()
    where id = 1;
  end if;
  return new;
end;
$$;

drop trigger if exists sismo_activa_emergencia on public.sismos;
create trigger sismo_activa_emergencia after insert on public.sismos
  for each row execute function public.auto_activar_emergencia_sismo();

-- Registrar migración
insert into public.migraciones (version, nombre)
values ('0014', 'Alertas sísmicas y emergencia geolocalizada')
on conflict do nothing;
