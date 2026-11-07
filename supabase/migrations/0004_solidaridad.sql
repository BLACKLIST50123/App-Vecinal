-- =====================================================================
-- Migración 0004 · Red de Solidaridad: colectas y respuestas
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
-- v4 · Red de Solidaridad: colectas del barrio y respuestas
-- =====================================================================

-- Colectas (responsabilidad social): meta de donaciones y avance
-- registrado a mano por quien organiza (donaciones entregadas en persona).
alter table public.publicaciones add column if not exists meta int
  check (meta is null or meta between 1 and 10000);
alter table public.publicaciones add column if not exists avance int not null default 0
  check (avance >= 0);

-- "ayudas" guarda la respuesta de un vecino: "Yo te ayudo" (pedido),
-- "Yo aporto" (colecta) o "Me interesa" (ofrecimiento). Solo los pedidos
-- pasan a "ya la están ayudando" con la primera respuesta.
create or replace function public.al_ofrecer_ayuda() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  select nombre into new.vecino_nombre from public.perfiles where id = new.vecino_id;
  update public.publicaciones set estado = 'en_curso'
   where id = new.publicacion_id and estado = 'abierta'
     and tipo = 'pido' and categoria <> 'colecta';
  return new;
end $$;

-- ---------------------------------------------------------------------

-- Esta migración requiere las anteriores.
insert into public.migraciones (version, nombre) values ('0001','Base'),('0002','Coordinación'),('0003','Confianza') on conflict do nothing;

insert into public.migraciones (version, nombre) values ('0004', 'Red de Solidaridad: colectas y respuestas') on conflict do nothing;
