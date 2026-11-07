-- =====================================================================
-- Migración 0002 · Coordinación: Yo ayudo, Visto Bueno verificado y tiempo real
-- Ejecutar UNA vez en Supabase > SQL Editor. Es segura de repetir.
-- =====================================================================

-- Registro de migraciones aplicadas (se crea si no existe).
create table if not exists public.migraciones (
  version     text primary key,
  nombre      text not null,
  aplicada_en timestamptz not null default now()
);
alter table public.migraciones enable row level security;
-- =====================================================================
-- v2 · Coordinación vecinal, Visto Bueno verificado y tiempo real
-- =====================================================================

-- Visto Bueno: se guarda si quien recomienda es vecino verificado por GPS
-- en la zona ("recomendaciones de vecinos de la misma zona").
alter table public.vistos_buenos
  add column if not exists autor_verificado boolean not null default false;

create or replace function public.poner_autor() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.autor_id is not null then
    select p.nombre, p.rol into new.autor_nombre, new.autor_rol
      from public.perfiles p where p.id = new.autor_id;
    if tg_table_name = 'vistos_buenos' then
      select p.verificado_gps into new.autor_verificado
        from public.perfiles p where p.id = new.autor_id;
    end if;
  elsif auth.role() in ('anon','authenticated') then
    new.autor_rol := null;
    if tg_table_name = 'vistos_buenos' then new.autor_verificado := false; end if;
  end if;
  return new;
end $$;

-- "Yo ayudo": cualquier vecino con cuenta se compromete a ayudar en un
-- pedido. El primero pasa el pedido a "ya están ayudando".
create table if not exists public.ayudas (
  publicacion_id uuid not null references public.publicaciones(id) on delete cascade,
  vecino_id      uuid not null references public.perfiles(id) on delete cascade default auth.uid(),
  vecino_nombre  text,
  created_at     timestamptz not null default now(),
  primary key (publicacion_id, vecino_id)
);

create or replace function public.al_ofrecer_ayuda() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  select nombre into new.vecino_nombre from public.perfiles where id = new.vecino_id;
  update public.publicaciones set estado = 'en_curso'
   where id = new.publicacion_id and estado = 'abierta';
  return new;
end $$;
drop trigger if exists ayudas_antes on public.ayudas;
create trigger ayudas_antes before insert on public.ayudas
  for each row execute function public.al_ofrecer_ayuda();

alter table public.ayudas enable row level security;
drop policy if exists ayudas_select on public.ayudas;
create policy ayudas_select on public.ayudas for select using (true);
drop policy if exists ayudas_insert on public.ayudas;
create policy ayudas_insert on public.ayudas for insert to authenticated
  with check (
    vecino_id = auth.uid()
    and not exists (select 1 from public.publicaciones p
                    where p.id = publicacion_id and p.autor_id = auth.uid())
  );
drop policy if exists ayudas_delete on public.ayudas;
create policy ayudas_delete on public.ayudas for delete to authenticated
  using (vecino_id = auth.uid());

-- Tiempo real: la emergencia y los pedidos nuevos llegan al instante.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and tablename = 'emergencia') then
      alter publication supabase_realtime add table public.emergencia;
    end if;
    if not exists (select 1 from pg_publication_tables
                   where pubname = 'supabase_realtime' and tablename = 'publicaciones') then
      alter publication supabase_realtime add table public.publicaciones;
    end if;
  end if;
end $$;


insert into public.migraciones (version, nombre) values ('0002', 'Coordinación: Yo ayudo, Visto Bueno verificado y tiempo real') on conflict do nothing;
