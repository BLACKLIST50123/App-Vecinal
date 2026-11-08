-- =====================================================================
-- 0016 · Recomendaciones de la misma zona y motivos de un toque
-- - Cada Visto Bueno guarda el SECTOR de quien recomienda (lo pone el
--   servidor desde su perfil; no se puede falsificar). Así la app muestra
--   el sello "Recomendado en tu barrio" (3+ vecinos verificados de tu
--   mismo sector), como pide el reto: "recomendaciones de vecinos de la
--   misma zona".
-- - Motivos: Puntual, Precio justo, Buen trabajo, Amable, De confianza.
-- Se puede ejecutar varias veces sin error.
-- =====================================================================

alter table public.vistos_buenos add column if not exists autor_sector text;
alter table public.vistos_buenos add column if not exists motivos text[] not null default '{}';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'vistos_buenos_motivos_validos') then
    alter table public.vistos_buenos add constraint vistos_buenos_motivos_validos check (
      cardinality(motivos) <= 5
      and motivos <@ array['puntual', 'precio_justo', 'buen_trabajo', 'amable', 'confiable']::text[]
    );
  end if;
end $$;

-- El sector lo copia el servidor del perfil de quien recomienda.
create or replace function public.vb_poner_sector() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- Vecinos con cuenta: el sector sale de su perfil. (Los datos de demo,
  -- sin cuenta, traen su sector desde seed.sql.)
  if new.autor_id is not null then
    new.autor_sector := (select p.sector from public.perfiles p where p.id = new.autor_id);
  end if;
  return new;
end $$;

drop trigger if exists vb_sector on public.vistos_buenos;
create trigger vb_sector before insert or update of autor_id on public.vistos_buenos
  for each row execute function public.vb_poner_sector();

-- Completar los Vistos Buenos que ya existían (datos de demo incluidos).
update public.vistos_buenos vb
   set autor_sector = p.sector
  from public.perfiles p
 where p.id = vb.autor_id and vb.autor_sector is null;

insert into public.migraciones (version, nombre)
values ('0016', 'recomendaciones_zona_y_motivos')
on conflict (version) do nothing;
