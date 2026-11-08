-- =====================================================================
-- Migración 0006 · Modo SOS: reportes de un toque desde cualquier pantalla
-- Ejecutar UNA vez en Supabase > SQL Editor. Es segura de repetir.
-- Requiere 0001–0005.
-- =====================================================================
-- Un SOS (auxilio médico, inseguridad, falta de agua, sismo) se puede
-- enviar en cualquier momento, con o sin cuenta, aunque la junta no haya
-- activado el modo emergencia. Llega al tablero de emergencia como
-- pedido "muy urgente" con ubicación aproximada.
-- =====================================================================

create table if not exists public.migraciones (
  version     text primary key,
  nombre      text not null,
  aplicada_en timestamptz not null default now()
);
alter table public.migraciones enable row level security;

-- Nuevo origen 'sos'.
alter table public.publicaciones drop constraint if exists publicaciones_origen_check;
alter table public.publicaciones add constraint publicaciones_origen_check
  check (origen in ('app','qr','sin_cuenta','sos'));

-- Vecino con cuenta: puede publicar a su nombre desde la app o desde el SOS.
drop policy if exists pub_insert_auth on public.publicaciones;
create policy pub_insert_auth on public.publicaciones for insert to authenticated
  with check (
    (autor_id = auth.uid() and origen in ('app','sos'))
    or (autor_id is null and origen in ('qr','sin_cuenta','sos'))
  );

-- Sin cuenta: pedidos de ayuda en emergencia activa (D5) o SOS en
-- cualquier momento.
drop policy if exists pub_insert_anon on public.publicaciones;
create policy pub_insert_anon on public.publicaciones for insert to anon
  with check (
    autor_id is null and es_emergencia and tipo = 'pido'
    and (
      origen = 'sos'
      or (origen in ('qr','sin_cuenta') and exists (select 1 from public.emergencia e where e.activa))
    )
  );

-- Anti-spam básico: máximo 3 SOS por la misma zona (≈ 200 m) en 10 minutos
-- cuando vienen sin cuenta.
create or replace function public.limitar_sos() returns trigger
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  if new.origen = 'sos' and new.autor_id is null then
    select count(*) into n from public.publicaciones p
     where p.origen = 'sos' and p.autor_id is null
       and p.created_at > now() - interval '10 minutes'
       and abs(coalesce(p.lat, 0) - coalesce(new.lat, 0)) < 0.002
       and abs(coalesce(p.lng, 0) - coalesce(new.lng, 0)) < 0.002;
    if n >= 3 then
      raise exception 'Demasiados SOS seguidos desde esta zona. Si es urgente, llama al 105 o al 106.'
        using errcode = 'P0001';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists publicaciones_limitar_sos on public.publicaciones;
create trigger publicaciones_limitar_sos before insert on public.publicaciones
  for each row execute function public.limitar_sos();

insert into public.migraciones (version, nombre)
  values ('0006', 'Modo SOS: reportes de un toque') on conflict do nothing;
