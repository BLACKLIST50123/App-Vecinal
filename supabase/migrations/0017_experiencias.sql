-- =====================================================================
-- 0017 · "No me fue bien": experiencias negativas PRIVADAS
-- Cuando un vecino responde "No me fue bien" en "¿Te atendió bien?", se
-- guarda aquí. Nadie lo ve en público (evita conflictos entre vecinos):
--  - Todos ven solo el TOTAL por servicio (baja un poco su puntaje).
--  - Solo la junta vecinal (moderador) ve los motivos, para revisar
--    servicios con varias quejas.
-- Un vecino, una queja por servicio. Se puede ejecutar varias veces.
-- =====================================================================

create table if not exists public.experiencias (
  id          uuid primary key default gen_random_uuid(),
  servicio_id uuid not null references public.servicios(id) on delete cascade,
  autor_id    uuid not null references public.perfiles(id) on delete cascade default auth.uid(),
  motivo      text check (motivo is null or motivo in ('no_vino', 'cobro_de_mas', 'mal_trabajo', 'mal_trato')),
  created_at  timestamptz not null default now(),
  unique (servicio_id, autor_id)
);

alter table public.experiencias enable row level security;

-- Cada vecino registra la suya (no sobre su propio servicio).
drop policy if exists exp_insert on public.experiencias;
create policy exp_insert on public.experiencias for insert to authenticated
  with check (
    autor_id = auth.uid()
    and not exists (select 1 from public.servicios s where s.id = servicio_id and s.autor_id = auth.uid())
  );

-- Solo la junta vecinal lee el detalle.
drop policy if exists exp_select on public.experiencias;
create policy exp_select on public.experiencias for select to authenticated
  using (public.mi_rol() = 'moderador');

-- Total de experiencias negativas por servicio (sin nombres). Lo usa la
-- app para restar en el puntaje de confianza.
create or replace function public.conteo_experiencias()
returns table (servicio_id uuid, total int)
language sql stable security definer set search_path = public as $$
  select e.servicio_id, count(*)::int from public.experiencias e group by e.servicio_id;
$$;
grant execute on function public.conteo_experiencias() to anon, authenticated;

-- Para la junta: servicios con 2 o más quejas, con sus motivos.
create or replace function public.servicios_con_quejas()
returns table (servicio_id uuid, titulo text, autor_nombre text, total int, motivos text[], ultima timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if public.mi_rol() <> 'moderador' then
    raise exception 'Solo la junta vecinal puede ver esto.' using errcode = 'P0001';
  end if;
  return query
    select s.id, s.titulo, s.autor_nombre, count(*)::int,
           array_remove(array_agg(distinct e.motivo), null), max(e.created_at)
      from public.experiencias e join public.servicios s on s.id = e.servicio_id
     group by s.id, s.titulo, s.autor_nombre
    having count(*) >= 2
     order by count(*) desc, max(e.created_at) desc;
end $$;
grant execute on function public.servicios_con_quejas() to authenticated;

insert into public.migraciones (version, nombre)
values ('0017', 'experiencias_negativas_privadas')
on conflict (version) do nothing;
