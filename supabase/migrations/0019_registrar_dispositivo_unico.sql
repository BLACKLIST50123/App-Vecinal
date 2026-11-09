-- =====================================================================
-- Migración 0019 · Una sola versión de registrar_dispositivo
-- La 0014 agregó p_sismos con "create or replace", pero como cambió la
-- lista de parámetros Postgres creó una SEGUNDA función en vez de
-- reemplazar la de la 0012. Con las dos, Supabase responde PGRST203
-- ("Could not choose the best candidate function") y ningún celular se
-- registra para recibir push. Aquí se borra la versión vieja (sin p_sismos).
-- Idempotente: es segura de ejecutar varias veces.
-- =====================================================================

drop function if exists public.registrar_dispositivo(
  text, boolean, boolean, boolean, boolean, boolean, text, double precision, double precision
);

insert into public.migraciones (version, nombre)
values ('0019', 'registrar_dispositivo_unico')
on conflict (version) do nothing;
