-- =====================================================================
-- Migración 0003 · Confianza: reportes, verificación y estados
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
-- v3 · Confianza y seguridad: reportes, verificación y estados
-- =====================================================================

-- Estados del modo emergencia: pendiente (abierta), en atención
-- (en_curso), atendido (resuelta) y no verificado.
alter table public.publicaciones drop constraint if exists publicaciones_estado_check;
alter table public.publicaciones add constraint publicaciones_estado_check
  check (estado in ('abierta','en_curso','resuelta','no_verificado'));

-- Diferencia un reporte ciudadano de uno verificado por una organización
-- o la junta vecinal.
alter table public.publicaciones add column if not exists verificada boolean not null default false;

-- Reportes de contenido (falso, estafa, discriminación...). Solo el
-- moderador los ve. Con 3 reportes de vecinos distintos el contenido se
-- oculta automáticamente hasta que el moderador lo revise.
create table if not exists public.reportes (
  id         uuid primary key default gen_random_uuid(),
  tabla      text not null check (tabla in ('publicaciones','servicios')),
  objeto_id  uuid not null,
  titulo     text,
  motivo     text not null check (motivo in ('falso','estafa','discriminacion','acusacion','datos_personales','otro')),
  detalle    text check (char_length(detalle) <= 300),
  autor_id   uuid references public.perfiles(id) on delete set null default auth.uid(),
  revisado   boolean not null default false,
  created_at timestamptz not null default now(),
  unique (tabla, objeto_id, autor_id)
);

create or replace function public.al_reportar() returns trigger
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  select count(distinct autor_id) into n from public.reportes
   where tabla = new.tabla and objeto_id = new.objeto_id and not revisado;
  if n >= 3 then
    if new.tabla = 'publicaciones' then
      update public.publicaciones set estado = 'no_verificado', verificada = false
       where id = new.objeto_id and estado <> 'resuelta';
    else
      update public.servicios set activo = false where id = new.objeto_id;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists reportes_despues on public.reportes;
create trigger reportes_despues after insert on public.reportes
  for each row execute function public.al_reportar();

alter table public.reportes enable row level security;
drop policy if exists reportes_insert on public.reportes;
create policy reportes_insert on public.reportes for insert to authenticated
  with check (autor_id = auth.uid());
drop policy if exists reportes_select on public.reportes;
create policy reportes_select on public.reportes for select to authenticated
  using (public.mi_rol() = 'moderador' or autor_id = auth.uid());
drop policy if exists reportes_update on public.reportes;
create policy reportes_update on public.reportes for update to authenticated
  using (public.mi_rol() = 'moderador');

-- El moderador también ve los servicios ocultos por reportes.
drop policy if exists servicios_select on public.servicios;
create policy servicios_select on public.servicios for select
  using (activo or autor_id = auth.uid() or public.mi_rol() = 'moderador');


insert into public.migraciones (version, nombre) values ('0003', 'Confianza: reportes, verificación y estados') on conflict do nothing;
