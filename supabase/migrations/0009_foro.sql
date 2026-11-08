-- =====================================================================
-- Migración 0009 · Foro Vecinal
-- Tablas, índices optimizados, triggers automáticos y políticas RLS
-- Idempotente: Es segura de ejecutar múltiples veces en Supabase.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABLA: foro_temas (Publicaciones y consultas comunitarias del barrio)
-- ---------------------------------------------------------------------
create table if not exists public.foro_temas (
  id                  uuid primary key default gen_random_uuid(),
  autor_id            uuid references auth.users(id) on delete set null,
  autor_nombre        text not null default 'Vecino',
  autor_rol           text default 'vecino',
  es_prestador        boolean not null default false,
  autor_oficio        text,
  sector              text not null,
  tipo                text not null
                      check (tipo in ('servicio', 'dialogo', 'recomendacion', 'aviso')),
  categoria_servicio  text,
  titulo              text not null,
  contenido           text not null,
  
  -- Coordenadas GPS de la consulta (Chimbote / Nuevo Chimbote)
  lat                 double precision,
  lng                 double precision,
  
  -- Contadores atómicos desnormalizados para lectura instantánea O(1) del feed
  apoyos_count        integer not null default 0,
  respuestas_count    integer not null default 0,
  estado              text not null default 'abierto'
                      check (estado in ('abierto', 'resuelto', 'cerrado')),
  
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 2. TABLA: foro_respuestas (Comentarios y respuestas al tema)
-- ---------------------------------------------------------------------
create table if not exists public.foro_respuestas (
  id                  uuid primary key default gen_random_uuid(),
  tema_id             uuid not null references public.foro_temas(id) on delete cascade,
  autor_id            uuid references auth.users(id) on delete set null,
  autor_nombre        text not null default 'Vecino',
  autor_rol           text default 'vecino',
  es_prestador        boolean not null default false,
  autor_oficio        text,
  vistos_buenos       integer not null default 0,
  sector              text,
  contenido           text not null,
  
  -- Contacto opcional si un prestador recomienda su servicio u oficio
  contacto_telefono   text,
  nombre_comercial    text,
  servicio_id         uuid references public.servicios(id) on delete set null,
  respondiendo_a      text,
  
  created_at          timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 3. TABLA: foro_apoyos (Interacciones de 'Apoyo' sin votos duplicados)
-- ---------------------------------------------------------------------
create table if not exists public.foro_apoyos (
  tema_id             uuid not null references public.foro_temas(id) on delete cascade,
  usuario_id          uuid not null references auth.users(id) on delete cascade,
  created_at          timestamptz not null default now(),
  primary key (tema_id, usuario_id)
);

-- ---------------------------------------------------------------------
-- 4. ÍNDICES DE ALTO RENDIMIENTO (OPTIMIZACIÓN DE CONSULTAS Y FILTROS)
-- ---------------------------------------------------------------------

-- A. Carga instantánea del feed principal ordenado por fecha
create index if not exists idx_foro_temas_feed 
  on public.foro_temas (created_at desc);

-- B. Filtro rápido por tipo de tema (servicio, diálogo, recomendación, aviso)
create index if not exists idx_foro_temas_tipo 
  on public.foro_temas (tipo, created_at desc);

-- C. Filtro por sector (Bellamar, Casco Urbano, Buenos Aires, etc.)
create index if not exists idx_foro_temas_sector 
  on public.foro_temas (sector, created_at desc);

-- D. Búsqueda de publicaciones del usuario logueado
create index if not exists idx_foro_temas_autor 
  on public.foro_temas (autor_id);

-- E. Carga cronológica de respuestas dentro de una conversación
create index if not exists idx_foro_respuestas_tema 
  on public.foro_respuestas (tema_id, created_at asc);

-- F. Filtrado por coordenadas GPS (cuando estén presentes)
create index if not exists idx_foro_temas_geo 
  on public.foro_temas (lat, lng) 
  where lat is not null and lng is not null;

-- ---------------------------------------------------------------------
-- 5. TRIGGERS Y FUNCIONES DE AUTOMATIZACIÓN
-- ---------------------------------------------------------------------

-- Trigger 1: Inyectar automáticamente autor, rol, sector y oficio desde el perfil
create or replace function public.fn_completar_autor_foro()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_perfil public.perfiles%rowtype;
begin
  if new.autor_id is null then
    new.autor_id := auth.uid();
  end if;

  if new.autor_id is not null then
    select * into v_perfil from public.perfiles where id = new.autor_id;
    if found then
      new.autor_nombre := coalesce(v_perfil.nombre, new.autor_nombre, 'Vecino');
      new.autor_rol := coalesce(v_perfil.rol, new.autor_rol, 'vecino');
      new.es_prestador := coalesce(v_perfil.es_prestador, false);
      if v_perfil.oficio is not null and v_perfil.oficio <> '' then
        new.autor_oficio := v_perfil.oficio;
      end if;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists tr_completar_autor_tema on public.foro_temas;
create trigger tr_completar_autor_tema
before insert on public.foro_temas
for each row execute function public.fn_completar_autor_foro();

drop trigger if exists tr_completar_autor_respuesta on public.foro_respuestas;
create trigger tr_completar_autor_respuesta
before insert on public.foro_respuestas
for each row execute function public.fn_completar_autor_foro();

-- Trigger 2: Mantener contador atómico de respuestas (sin COUNT(*) pesado en feed)
create or replace function public.fn_actualizar_contador_respuestas_foro()
returns trigger language plpgsql as $$
begin
  if (TG_OP = 'INSERT') then
    update public.foro_temas set respuestas_count = respuestas_count + 1 where id = new.tema_id;
  elsif (TG_OP = 'DELETE') then
    update public.foro_temas set respuestas_count = greatest(0, respuestas_count - 1) where id = old.tema_id;
  end if;
  return null;
end;
$$;

drop trigger if exists tr_foro_respuestas_count on public.foro_respuestas;
create trigger tr_foro_respuestas_count
after insert or delete on public.foro_respuestas
for each row execute function public.fn_actualizar_contador_respuestas_foro();

-- Trigger 3: Mantener contador atómico de apoyos
create or replace function public.fn_actualizar_contador_apoyos_foro()
returns trigger language plpgsql as $$
begin
  if (TG_OP = 'INSERT') then
    update public.foro_temas set apoyos_count = apoyos_count + 1 where id = new.tema_id;
  elsif (TG_OP = 'DELETE') then
    update public.foro_temas set apoyos_count = greatest(0, apoyos_count - 1) where id = old.tema_id;
  end if;
  return null;
end;
$$;

drop trigger if exists tr_foro_apoyos_count on public.foro_apoyos;
create trigger tr_foro_apoyos_count
after insert or delete on public.foro_apoyos
for each row execute function public.fn_actualizar_contador_apoyos_foro();

-- ---------------------------------------------------------------------
-- 6. POLÍTICAS DE SEGURIDAD (Row Level Security - RLS)
-- ---------------------------------------------------------------------
alter table public.foro_temas enable row level security;
alter table public.foro_respuestas enable row level security;
alter table public.foro_apoyos enable row level security;

-- Lectura pública (todos los vecinos pueden leer los temas y comentarios)
drop policy if exists foro_temas_select on public.foro_temas;
create policy foro_temas_select on public.foro_temas for select using (true);

drop policy if exists foro_respuestas_select on public.foro_respuestas;
create policy foro_respuestas_select on public.foro_respuestas for select using (true);

drop policy if exists foro_apoyos_select on public.foro_apoyos;
create policy foro_apoyos_select on public.foro_apoyos for select using (true);

-- Inserción exclusiva para vecinos autenticados
drop policy if exists foro_temas_insert on public.foro_temas;
create policy foro_temas_insert on public.foro_temas for insert
  with check (auth.role() = 'authenticated');

drop policy if exists foro_respuestas_insert on public.foro_respuestas;
create policy foro_respuestas_insert on public.foro_respuestas for insert
  with check (auth.role() = 'authenticated');

drop policy if exists foro_apoyos_insert on public.foro_apoyos;
create policy foro_apoyos_insert on public.foro_apoyos for insert
  with check (auth.role() = 'authenticated' and usuario_id = auth.uid());

-- Actualización (solo el autor que creó el tema o respuesta)
drop policy if exists foro_temas_update on public.foro_temas;
create policy foro_temas_update on public.foro_temas for update
  using (autor_id = auth.uid());

drop policy if exists foro_respuestas_update on public.foro_respuestas;
create policy foro_respuestas_update on public.foro_respuestas for update
  using (autor_id = auth.uid());

drop policy if exists foro_apoyos_update on public.foro_apoyos;
create policy foro_apoyos_update on public.foro_apoyos for update
  using (usuario_id = auth.uid());

-- Eliminación (solo el autor que creó el tema, respuesta o apoyo)
drop policy if exists foro_temas_delete on public.foro_temas;
create policy foro_temas_delete on public.foro_temas for delete
  using (autor_id = auth.uid());

drop policy if exists foro_respuestas_delete on public.foro_respuestas;
create policy foro_respuestas_delete on public.foro_respuestas for delete
  using (autor_id = auth.uid());

drop policy if exists foro_apoyos_delete on public.foro_apoyos;
create policy foro_apoyos_delete on public.foro_apoyos for delete
  using (usuario_id = auth.uid());

-- ---------------------------------------------------------------------
-- 7. PERMISOS EXPLÍCITOS (GRANTS)
-- ---------------------------------------------------------------------
grant select on public.foro_temas to anon, authenticated;
grant select on public.foro_respuestas to anon, authenticated;
grant select on public.foro_apoyos to anon, authenticated;

grant insert, update, delete on public.foro_temas to authenticated;
grant insert, update, delete on public.foro_respuestas to authenticated;
grant insert, update, delete on public.foro_apoyos to authenticated;

-- ---------------------------------------------------------------------
-- 8. TIEMPO REAL (Supabase Realtime)
-- Permite que los nuevos temas y respuestas aparezcan en vivo en la app
-- ---------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'foro_temas') then
      alter publication supabase_realtime add table public.foro_temas;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'foro_respuestas') then
      alter publication supabase_realtime add table public.foro_respuestas;
    end if;
  end if;
end $$;

-- ---------------------------------------------------------------------
-- 9. REGISTRO DE MIGRACIÓN
-- ---------------------------------------------------------------------
insert into public.migraciones (version, nombre)
values ('0009', 'foro_vecinal')
on conflict (version) do nothing;
