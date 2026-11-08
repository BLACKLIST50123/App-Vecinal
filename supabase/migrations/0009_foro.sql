-- =====================================================================
-- MIGRACIÓN 0009 · MÓDULO DE FORO VECINAL
-- =====================================================================
-- Arquitectura completa: Tablas unificadas, compatibilidad retroactiva,
-- índices de alto rendimiento, disparadores automáticos, políticas RLS,
-- permisos de acceso, soporte en tiempo real y sincronización atómica.
--
-- Idempotente: Es 100% segura de ejecutar múltiples veces en Supabase.
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
  
  -- Coordenadas GPS opcionales de la consulta en el mapa
  lat                 double precision,
  lng                 double precision,
  
  -- Contadores atómicos desnormalizados para lectura instantánea O(1) del feed
  apoyos_count        integer not null default 0,
  dislikes_count      integer not null default 0,
  respuestas_count    integer not null default 0,
  estado              text not null default 'abierto'
                      check (estado in ('abierto', 'resuelto', 'cerrado')),
  
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 2. TABLA: foro_respuestas (Comentarios, respuestas y recomendaciones)
-- ---------------------------------------------------------------------
create table if not exists public.foro_respuestas (
  id                  uuid primary key default gen_random_uuid(),
  tema_id             uuid not null references public.foro_temas(id) on delete cascade,
  autor_id            uuid references auth.users(id) on delete set null,
  autor_nombre        text not null default 'Vecino',
  autor_rol           text default 'vecino',
  es_prestador        boolean not null default false,
  autor_oficio        text,
  sector              text,
  contenido           text not null,
  
  -- Ficha de recomendación si un vecino o prestador comparte un contacto profesional
  contacto_telefono   text,
  nombre_comercial    text,
  servicio_id         uuid references public.servicios(id) on delete set null,
  
  -- Hilos jerárquicos estilo Instagram
  respuesta_a_id      uuid references public.foro_respuestas(id) on delete cascade,
  respondiendo_a      text,
  
  -- Contadores de reacciones en comentarios
  likes_count         integer not null default 0,
  dislikes_count      integer not null default 0,
  vistos_buenos       integer not null default 0,
  
  created_at          timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 3. TABLA: foro_apoyos (Reacciones Like y Dislike en publicaciones)
-- ---------------------------------------------------------------------
create table if not exists public.foro_apoyos (
  tema_id             uuid not null references public.foro_temas(id) on delete cascade,
  usuario_id          uuid not null references auth.users(id) on delete cascade,
  tipo                text not null default 'like' check (tipo in ('like', 'dislike')),
  created_at          timestamptz not null default now(),
  primary key (tema_id, usuario_id)
);

-- ---------------------------------------------------------------------
-- 4. TABLA: foro_respuestas_likes (Reacciones Like y Dislike en comentarios)
-- ---------------------------------------------------------------------
create table if not exists public.foro_respuestas_likes (
  respuesta_id        uuid not null references public.foro_respuestas(id) on delete cascade,
  usuario_id          uuid not null references auth.users(id) on delete cascade,
  tipo                text not null default 'like' check (tipo in ('like', 'dislike')),
  created_at          timestamptz not null default now(),
  primary key (respuesta_id, usuario_id)
);

-- ---------------------------------------------------------------------
-- 5. COMPATIBILIDAD RETROACTIVA (Idempotencia en bases de datos existentes)
-- ---------------------------------------------------------------------
-- Asegurar que las columnas agregadas recientemente existan si las tablas ya fueron creadas antes
alter table public.foro_temas 
  add column if not exists dislikes_count integer not null default 0;

alter table public.foro_respuestas 
  add column if not exists respuesta_a_id uuid references public.foro_respuestas(id) on delete cascade,
  add column if not exists respondiendo_a text,
  add column if not exists likes_count integer not null default 0,
  add column if not exists dislikes_count integer not null default 0;

alter table public.foro_apoyos 
  add column if not exists tipo text not null default 'like';

alter table public.foro_respuestas_likes 
  add column if not exists tipo text not null default 'like';

-- ---------------------------------------------------------------------
-- 6. ÍNDICES DE ALTO RENDIMIENTO (OPTIMIZACIÓN DE CONSULTAS Y FILTROS)
-- ---------------------------------------------------------------------
-- Índices en foro_temas
create index if not exists idx_foro_temas_feed 
  on public.foro_temas (created_at desc);

create index if not exists idx_foro_temas_tipo 
  on public.foro_temas (tipo, created_at desc);

create index if not exists idx_foro_temas_sector 
  on public.foro_temas (sector, created_at desc);

create index if not exists idx_foro_temas_autor 
  on public.foro_temas (autor_id);

create index if not exists idx_foro_temas_geo 
  on public.foro_temas (lat, lng) 
  where lat is not null and lng is not null;

-- Índices en foro_respuestas
create index if not exists idx_foro_respuestas_tema 
  on public.foro_respuestas (tema_id, created_at asc);

create index if not exists idx_foro_respuestas_padre 
  on public.foro_respuestas (respuesta_a_id);

-- Índices en tablas de reacciones
create index if not exists idx_foro_apoyos_usuario 
  on public.foro_apoyos (usuario_id);

create index if not exists idx_foro_respuestas_likes_usuario 
  on public.foro_respuestas_likes (usuario_id);

-- ---------------------------------------------------------------------
-- 7. TRIGGERS Y FUNCIONES DE AUTOMATIZACIÓN
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

-- Trigger 2: Mantener contador atómico de respuestas en foro_temas
create or replace function public.fn_actualizar_contador_respuestas_foro()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_tema_id uuid;
begin
  v_tema_id := coalesce(new.tema_id, old.tema_id);
  update public.foro_temas
  set respuestas_count = (select count(*) from public.foro_respuestas where tema_id = v_tema_id)
  where id = v_tema_id;
  return null;
end;
$$;

drop trigger if exists tr_foro_respuestas_count on public.foro_respuestas;
create trigger tr_foro_respuestas_count
after insert or delete on public.foro_respuestas
for each row execute function public.fn_actualizar_contador_respuestas_foro();

-- Trigger 3: Mantener contadores atómicos de apoyos (Likes y Dislikes en Temas)
create or replace function public.fn_actualizar_contador_apoyos_foro()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_tema_id uuid;
begin
  v_tema_id := coalesce(new.tema_id, old.tema_id);
  update public.foro_temas
  set
    apoyos_count = (select count(*) from public.foro_apoyos where tema_id = v_tema_id and coalesce(tipo, 'like') = 'like'),
    dislikes_count = (select count(*) from public.foro_apoyos where tema_id = v_tema_id and tipo = 'dislike')
  where id = v_tema_id;
  return null;
end;
$$;

drop trigger if exists tr_foro_apoyos_count on public.foro_apoyos;
create trigger tr_foro_apoyos_count
after insert or update or delete on public.foro_apoyos
for each row execute function public.fn_actualizar_contador_apoyos_foro();

-- Trigger 4: Mantener contadores atómicos de Likes y Dislikes en Comentarios
create or replace function public.fn_actualizar_likes_respuesta()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_resp_id uuid;
begin
  v_resp_id := coalesce(new.respuesta_id, old.respuesta_id);
  update public.foro_respuestas
  set
    likes_count = (select count(*) from public.foro_respuestas_likes where respuesta_id = v_resp_id and coalesce(tipo, 'like') = 'like'),
    dislikes_count = (select count(*) from public.foro_respuestas_likes where respuesta_id = v_resp_id and tipo = 'dislike')
  where id = v_resp_id;
  return null;
end;
$$;

drop trigger if exists trg_actualizar_likes_respuesta on public.foro_respuestas_likes;
create trigger trg_actualizar_likes_respuesta
after insert or update or delete on public.foro_respuestas_likes
for each row execute function public.fn_actualizar_likes_respuesta();

-- ---------------------------------------------------------------------
-- 8. POLÍTICAS DE SEGURIDAD (Row Level Security - RLS)
-- ---------------------------------------------------------------------
alter table public.foro_temas enable row level security;
alter table public.foro_respuestas enable row level security;
alter table public.foro_apoyos enable row level security;
alter table public.foro_respuestas_likes enable row level security;

-- Lectura pública (todos los vecinos pueden ver las publicaciones y reacciones)
drop policy if exists foro_temas_select on public.foro_temas;
create policy foro_temas_select on public.foro_temas for select using (true);

drop policy if exists foro_respuestas_select on public.foro_respuestas;
create policy foro_respuestas_select on public.foro_respuestas for select using (true);

drop policy if exists foro_apoyos_select on public.foro_apoyos;
create policy foro_apoyos_select on public.foro_apoyos for select using (true);

drop policy if exists foro_respuestas_likes_select on public.foro_respuestas_likes;
create policy foro_respuestas_likes_select on public.foro_respuestas_likes for select using (true);

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

drop policy if exists foro_respuestas_likes_insert on public.foro_respuestas_likes;
create policy foro_respuestas_likes_insert on public.foro_respuestas_likes for insert 
  with check (auth.role() = 'authenticated' and usuario_id = auth.uid());

-- Actualización (cambiar reacción de like a dislike, o editar su propio contenido)
drop policy if exists foro_temas_update on public.foro_temas;
create policy foro_temas_update on public.foro_temas for update
  using (autor_id = auth.uid());

drop policy if exists foro_respuestas_update on public.foro_respuestas;
create policy foro_respuestas_update on public.foro_respuestas for update
  using (autor_id = auth.uid());

drop policy if exists foro_apoyos_update on public.foro_apoyos;
create policy foro_apoyos_update on public.foro_apoyos for update
  using (usuario_id = auth.uid());

drop policy if exists foro_respuestas_likes_update on public.foro_respuestas_likes;
create policy foro_respuestas_likes_update on public.foro_respuestas_likes for update
  using (usuario_id = auth.uid());

-- Eliminación (retirar su propio like/dislike o borrar su publicación)
drop policy if exists foro_temas_delete on public.foro_temas;
create policy foro_temas_delete on public.foro_temas for delete
  using (autor_id = auth.uid());

drop policy if exists foro_respuestas_delete on public.foro_respuestas;
create policy foro_respuestas_delete on public.foro_respuestas for delete
  using (autor_id = auth.uid());

drop policy if exists foro_apoyos_delete on public.foro_apoyos;
create policy foro_apoyos_delete on public.foro_apoyos for delete
  using (usuario_id = auth.uid());

drop policy if exists foro_respuestas_likes_delete on public.foro_respuestas_likes;
create policy foro_respuestas_likes_delete on public.foro_respuestas_likes for delete 
  using (usuario_id = auth.uid());

-- ---------------------------------------------------------------------
-- 9. PERMISOS EXPLÍCITOS (GRANTS)
-- ---------------------------------------------------------------------
grant select on public.foro_temas to anon, authenticated;
grant select on public.foro_respuestas to anon, authenticated;
grant select on public.foro_apoyos to anon, authenticated;
grant select on public.foro_respuestas_likes to anon, authenticated;

grant insert, update, delete on public.foro_temas to authenticated;
grant insert, update, delete on public.foro_respuestas to authenticated;
grant insert, update, delete on public.foro_apoyos to authenticated;
grant insert, update, delete on public.foro_respuestas_likes to authenticated;

-- ---------------------------------------------------------------------
-- 10. TIEMPO REAL (Supabase Realtime) Y SINCRONIZACIÓN ATÓMICA
-- ---------------------------------------------------------------------
alter table public.foro_temas replica identity full;
alter table public.foro_respuestas replica identity full;
alter table public.foro_apoyos replica identity full;
alter table public.foro_respuestas_likes replica identity full;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'foro_temas') then
      alter publication supabase_realtime add table public.foro_temas;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'foro_respuestas') then
      alter publication supabase_realtime add table public.foro_respuestas;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'foro_apoyos') then
      alter publication supabase_realtime add table public.foro_apoyos;
    end if;
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'foro_respuestas_likes') then
      alter publication supabase_realtime add table public.foro_respuestas_likes;
    end if;
  end if;
end $$;

-- Sincronizar todos los datos existentes para garantizar concordancia exacta
update public.foro_temas t
set 
  apoyos_count = (select count(*) from public.foro_apoyos a where a.tema_id = t.id and coalesce(a.tipo, 'like') = 'like'),
  dislikes_count = (select count(*) from public.foro_apoyos a where a.tema_id = t.id and a.tipo = 'dislike'),
  respuestas_count = (select count(*) from public.foro_respuestas r where r.tema_id = t.id);

update public.foro_respuestas r
set 
  likes_count = (select count(*) from public.foro_respuestas_likes l where l.respuesta_id = r.id and coalesce(l.tipo, 'like') = 'like'),
  dislikes_count = (select count(*) from public.foro_respuestas_likes l where l.respuesta_id = r.id and l.tipo = 'dislike');

-- Registro formal en la tabla de migraciones
insert into public.migraciones (version, nombre)
values ('0009', 'foro_vecinal')
on conflict (version) do nothing;
