-- =====================================================================
-- Migración 0006 · Aportes y Pedidos de Servicios
-- Permite a los vecinos solicitar servicios/productos/clases desde la app,
-- y a los prestadores administrar sus pedidos y publicaciones en "Mis aportes".
-- =====================================================================

create table if not exists public.pedidos_servicio (
  id               uuid primary key default gen_random_uuid(),
  servicio_id      uuid not null references public.servicios(id) on delete cascade,
  prestador_id     uuid not null references public.perfiles(id) on delete cascade,
  cliente_id       uuid references public.perfiles(id) on delete set null default auth.uid(),
  cliente_nombre   text not null,
  cliente_telefono text,
  cliente_sector   text,
  detalle          text not null check (char_length(detalle) between 2 and 1000),
  fecha_deseada    text,
  estado           text not null default 'pendiente'
                   check (estado in ('pendiente', 'aceptado', 'en_proceso', 'completado', 'cancelado')),
  created_at       timestamptz not null default now()
);

create index if not exists pedidos_prestador_idx on public.pedidos_servicio (prestador_id, created_at desc);
create index if not exists pedidos_cliente_idx on public.pedidos_servicio (cliente_id, created_at desc);

-- RLS: Seguridad a nivel de fila
alter table public.pedidos_servicio enable row level security;

drop policy if exists pedidos_select on public.pedidos_servicio;
create policy pedidos_select on public.pedidos_servicio for select to authenticated
  using (prestador_id = auth.uid() or cliente_id = auth.uid() or public.mi_rol() = 'moderador');

drop policy if exists pedidos_insert on public.pedidos_servicio;
create policy pedidos_insert on public.pedidos_servicio for insert to authenticated
  with check (
    (cliente_id is null or cliente_id = auth.uid())
    and prestador_id != auth.uid() -- no te pides a ti mismo
  );

drop policy if exists pedidos_update on public.pedidos_servicio;
create policy pedidos_update on public.pedidos_servicio for update to authenticated
  using (prestador_id = auth.uid() or cliente_id = auth.uid() or public.mi_rol() = 'moderador')
  with check (prestador_id = auth.uid() or cliente_id = auth.uid() or public.mi_rol() = 'moderador');

drop policy if exists pedidos_delete on public.pedidos_servicio;
create policy pedidos_delete on public.pedidos_servicio for delete to authenticated
  using (prestador_id = auth.uid() or public.mi_rol() = 'moderador');

grant select, insert, update, delete on public.pedidos_servicio to authenticated;

-- Activa automáticamente la marca de prestador en el perfil al publicar un servicio
create or replace function public.marcar_prestador_al_publicar() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.autor_id is not null and not new.es_emergencia then
    update public.perfiles
       set es_prestador = true
     where id = new.autor_id and es_prestador = false;
  end if;
  return new;
end $$;

drop trigger if exists al_crear_servicio_marcar_prestador on public.servicios;
create trigger al_crear_servicio_marcar_prestador after insert on public.servicios
  for each row execute function public.marcar_prestador_al_publicar();

-- Tiempo real: avisar al prestador cuando le llega un nuevo pedido
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and tablename = 'pedidos_servicio') then
      alter publication supabase_realtime add table public.pedidos_servicio;
    end if;
  end if;
end $$;

insert into public.migraciones (version, nombre)
values ('0006', 'Aportes y Pedidos de Servicios')
on conflict do nothing;

