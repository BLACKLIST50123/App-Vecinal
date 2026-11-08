-- =====================================================================
-- Migración 0007 · SOS seguro: avisos reservados y límite por cuenta
-- Ejecutar UNA vez en Supabase > SQL Editor. Es segura de repetir.
-- Requiere 0001–0006.
-- =====================================================================
-- 1) Avisos RESERVADOS (secuestro, extorsión, violencia): publicarlos para
--    todos podría alertar al agresor. Solo los ven quien lo envió, la junta
--    vecinal (moderador) y las organizaciones de apoyo. Lo aplica el
--    servidor (RLS), no solo la app.
-- 2) Límite anti-spam también para cuentas: máximo 3 SOS cada 10 minutos.
-- =====================================================================

create table if not exists public.migraciones (
  version     text primary key,
  nombre      text not null,
  aplicada_en timestamptz not null default now()
);
alter table public.migraciones enable row level security;

alter table public.publicaciones add column if not exists visibilidad text not null default 'publica';
alter table public.publicaciones drop constraint if exists publicaciones_visibilidad_check;
alter table public.publicaciones add constraint publicaciones_visibilidad_check
  check (visibilidad in ('publica','restringida'));

drop policy if exists pub_select on public.publicaciones;
create policy pub_select on public.publicaciones for select
  using (
    visibilidad = 'publica'
    or autor_id = auth.uid()
    or public.mi_rol() in ('organizacion','moderador')
  );

-- Anti-spam: por zona sin cuenta (0006) + por cuenta.
create or replace function public.limitar_sos() returns trigger
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if new.origen = 'sos' then
    if new.autor_id is null then
      select count(*) into n from public.publicaciones p
       where p.origen = 'sos' and p.autor_id is null
         and p.created_at > now() - interval '10 minutes'
         and abs(coalesce(p.lat, 0) - coalesce(new.lat, 0)) < 0.002
         and abs(coalesce(p.lng, 0) - coalesce(new.lng, 0)) < 0.002;
    else
      select count(*) into n from public.publicaciones p
       where p.origen = 'sos' and p.autor_id = new.autor_id
         and p.created_at > now() - interval '10 minutes';
    end if;
    if n >= 3 then
      raise exception 'Ya enviaste varios SOS seguidos. Si es urgente, llama al 105 o al 106.'
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end $$;

create index if not exists publicaciones_sos_idx on public.publicaciones (origen, estado, created_at desc);

insert into public.migraciones (version, nombre)
  values ('0007', 'SOS seguro: avisos reservados y límite por cuenta') on conflict do nothing;
