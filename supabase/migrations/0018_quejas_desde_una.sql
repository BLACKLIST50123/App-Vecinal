-- =====================================================================
-- 0018 · La junta ve los servicios desde la PRIMERA queja
-- En 0017 solo se listaban servicios con 2 o más quejas; como cada vecino
-- se queja una sola vez por servicio, la junta no veía nada al inicio.
-- Ahora ve todos (la app marca "Atención" con 2 y "En revisión" con 3).
-- Se puede ejecutar varias veces sin error.
-- =====================================================================

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
     order by count(*) desc, max(e.created_at) desc;
end $$;
grant execute on function public.servicios_con_quejas() to authenticated;

insert into public.migraciones (version, nombre)
values ('0018', 'quejas_desde_una')
on conflict (version) do nothing;
