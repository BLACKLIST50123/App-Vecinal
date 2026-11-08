-- =====================================================================
-- Migración 0011 · Brigadistas nombrados por la junta vecinal y canales
-- de comunicación del sector.
--   - La junta vecinal (rol 'moderador') nombra brigadistas SOLO entre
--     los vecinos de su sector. El vecino debe aceptar.
--   - La junta publica canales del sector: públicos (todos los vecinos)
--     o solo para brigadistas (coordinación privada fuera de la app).
-- Idempotente: se puede ejecutar más de una vez.
-- =====================================================================

create or replace function public.mi_sector() returns text
language sql stable security definer set search_path = public as $$
  select sector from public.perfiles where id = auth.uid();
$$;

-- ---------------------------------------------------------------------
-- Brigadistas
-- ---------------------------------------------------------------------
create table if not exists public.brigadistas (
  vecino_id    uuid primary key references public.perfiles(id) on delete cascade,
  sector       text not null,
  especialidad text not null default 'general'
               check (especialidad in ('primeros_auxilios','rescate','evacuacion','logistica','comunicacion','general')),
  estado       text not null default 'invitado' check (estado in ('invitado','activo')),
  nombrado_por uuid references public.perfiles(id) on delete set null default auth.uid(),
  created_at   timestamptz not null default now(),
  aceptado_en  timestamptz
);
create index if not exists brigadistas_sector_idx on public.brigadistas (sector, estado);

create or replace function public.es_brigadista() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.brigadistas where vecino_id = auth.uid() and estado = 'activo');
$$;

alter table public.brigadistas enable row level security;

-- Ver: el propio vecino, la junta y las organizaciones; los brigadistas
-- activos son visibles para todos (nombre y especialidad, sin datos privados).
drop policy if exists brig_select on public.brigadistas;
create policy brig_select on public.brigadistas for select using (
  vecino_id = auth.uid()
  or estado = 'activo'
  or public.mi_rol() in ('moderador','organizacion')
);

-- Nombrar: solo la junta, solo vecinos de SU sector, nunca a sí misma,
-- y siempre como "invitado" (el vecino decide si acepta).
drop policy if exists brig_insert on public.brigadistas;
create policy brig_insert on public.brigadistas for insert to authenticated with check (
  public.mi_rol() = 'moderador'
  and estado = 'invitado'
  and vecino_id <> auth.uid()
  and sector = public.mi_sector()
  and exists (select 1 from public.perfiles p where p.id = vecino_id and p.sector = public.mi_sector())
);

-- Aceptar: solo el propio vecino, y solo puede pasar a "activo".
drop policy if exists brig_update on public.brigadistas;
create policy brig_update on public.brigadistas for update to authenticated
  using (vecino_id = auth.uid())
  with check (vecino_id = auth.uid() and estado = 'activo');

-- Quitar (junta de su sector) o renunciar / "Ahora no" (el propio vecino).
drop policy if exists brig_delete on public.brigadistas;
create policy brig_delete on public.brigadistas for delete to authenticated using (
  vecino_id = auth.uid()
  or (public.mi_rol() = 'moderador' and sector = public.mi_sector())
);

grant select on public.brigadistas to anon, authenticated;
grant insert, delete on public.brigadistas to authenticated;
revoke update on public.brigadistas from authenticated;
grant update (estado, aceptado_en) on public.brigadistas to authenticated;

-- ---------------------------------------------------------------------
-- Canales de comunicación del sector
-- ---------------------------------------------------------------------
create table if not exists public.canales_sector (
  id         uuid primary key default gen_random_uuid(),
  sector     text not null,
  tipo       text not null check (tipo in ('whatsapp','telegram','telefono','reunion','otro')),
  etiqueta   text not null check (char_length(etiqueta) between 2 and 60),
  valor      text not null check (char_length(valor) between 2 and 300),
  publico    boolean not null default true,
  creado_por uuid references public.perfiles(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);
create index if not exists canales_sector_idx on public.canales_sector (sector);

alter table public.canales_sector enable row level security;

drop policy if exists canal_select on public.canales_sector;
create policy canal_select on public.canales_sector for select using (
  publico
  or public.mi_rol() in ('moderador','organizacion')
  or (public.es_brigadista() and sector = public.mi_sector())
);

drop policy if exists canal_escribir on public.canales_sector;
create policy canal_escribir on public.canales_sector for all to authenticated
  using (public.mi_rol() = 'moderador' and sector = public.mi_sector())
  with check (public.mi_rol() = 'moderador' and sector = public.mi_sector());

grant select on public.canales_sector to anon, authenticated;
grant insert, update, delete on public.canales_sector to authenticated;

-- Tiempo real: el vecino ve su nombramiento al instante.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime' and tablename = 'brigadistas') then
    alter publication supabase_realtime add table public.brigadistas;
  end if;
end $$;

-- Si se ejecutó antes con el número 0010, se corrige el registro.
update public.migraciones set version = '0011'
  where version = '0010' and nombre like 'Brigadistas%';

insert into public.migraciones (version, nombre)
values ('0011', 'Brigadistas nombrados por la junta y canales del sector')
on conflict do nothing;
