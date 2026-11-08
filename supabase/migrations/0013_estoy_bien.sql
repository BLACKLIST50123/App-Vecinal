-- =====================================================================
-- Migración 0013 · "Estoy bien / Necesito ayuda" durante una emergencia
-- Cada vecino avisa cómo está con un toque. La junta, las organizaciones
-- y los brigadistas ven cuántos vecinos están a salvo y cuántos necesitan
-- ayuda. Una respuesta por vecino y por emergencia (se identifica por la
-- hora en que se activó: emergencia.actualizado_en).
-- Idempotente: se puede ejecutar más de una vez.
-- =====================================================================

create table if not exists public.estados_vecino (
  vecino_id        uuid not null references public.perfiles(id) on delete cascade default auth.uid(),
  emergencia_desde timestamptz not null,
  estado           text not null check (estado in ('bien','ayuda')),
  sector           text,
  actualizado_en   timestamptz not null default now(),
  primary key (vecino_id, emergencia_desde)
);
create index if not exists estados_vecino_emergencia_idx on public.estados_vecino (emergencia_desde, estado);

alter table public.estados_vecino enable row level security;

-- Ver: el propio vecino, y quienes coordinan (junta, organizaciones, brigadistas).
drop policy if exists estado_select on public.estados_vecino;
create policy estado_select on public.estados_vecino for select to authenticated using (
  vecino_id = auth.uid()
  or public.mi_rol() in ('moderador','organizacion')
  or public.es_brigadista()
);

-- Cada vecino solo escribe su propio estado.
drop policy if exists estado_insert on public.estados_vecino;
create policy estado_insert on public.estados_vecino for insert to authenticated
  with check (vecino_id = auth.uid());

drop policy if exists estado_update on public.estados_vecino;
create policy estado_update on public.estados_vecino for update to authenticated
  using (vecino_id = auth.uid()) with check (vecino_id = auth.uid());

grant select, insert, update on public.estados_vecino to authenticated;

-- Tiempo real: el conteo de la junta se actualiza al instante.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime' and tablename = 'estados_vecino') then
    alter publication supabase_realtime add table public.estados_vecino;
  end if;
end $$;

-- Si se ejecutó antes con el número 0012, se corrige el registro.
update public.migraciones set version = '0013'
  where version = '0012' and nombre like 'Estoy bien%';

insert into public.migraciones (version, nombre)
values ('0013', 'Estoy bien / Necesito ayuda en emergencia')
on conflict do nothing;
