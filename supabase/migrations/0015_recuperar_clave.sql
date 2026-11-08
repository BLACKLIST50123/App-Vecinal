-- =====================================================================
-- 0015 · Recuperar la clave con un código (sin SMS ni correo)
-- Al crear la cuenta, el vecino recibe un código de 8 caracteres
-- (ej. K7PM-3QXD). Con su celular + ese código pone una clave nueva.
-- Si lo pierde, la junta vecinal (moderador) le da uno nuevo en persona.
-- Solo se guarda el código cifrado (bcrypt). Cada código sirve una vez.
-- Se puede ejecutar varias veces sin error.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.codigos_recuperacion (
  usuario         uuid primary key references auth.users(id) on delete cascade,
  codigo_hash     text not null,
  creado_en       timestamptz not null default now(),
  intentos        int not null default 0,
  bloqueado_hasta timestamptz
);
-- Nadie lee esta tabla desde la app: solo las funciones de abajo.
alter table public.codigos_recuperacion enable row level security;
revoke all on public.codigos_recuperacion from anon, authenticated;

-- Genera un código nuevo para un usuario, guarda su hash y lo devuelve.
-- Sin letras que se confunden (0/O, 1/I/L).
create or replace function public._nuevo_codigo(p_usuario uuid) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare
  abc constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  b bytea := gen_random_bytes(8);
  c text := '';
begin
  for i in 0..7 loop
    c := c || substr(abc, (get_byte(b, i) % length(abc)) + 1, 1);
  end loop;
  insert into public.codigos_recuperacion (usuario, codigo_hash)
  values (p_usuario, crypt(c, gen_salt('bf')))
  on conflict (usuario) do update
    set codigo_hash = excluded.codigo_hash, creado_en = now(), intentos = 0, bloqueado_hasta = null;
  return substr(c, 1, 4) || '-' || substr(c, 5, 4);
end $$;
revoke all on function public._nuevo_codigo(uuid) from public, anon, authenticated;

-- El vecino con sesión pide su código (al registrarse o desde Perfil).
-- Crear uno nuevo anula el anterior.
create or replace function public.crear_codigo_recuperacion() returns text
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Necesitas iniciar sesión.' using errcode = 'P0001';
  end if;
  return public._nuevo_codigo(auth.uid());
end $$;
grant execute on function public.crear_codigo_recuperacion() to authenticated;

-- Cambiar la clave con el código. Funciona sin sesión.
-- 5 intentos fallidos bloquean 15 minutos. Devuelve un JSON:
--   {"ok": true, "codigo": "<código NUEVO>"}  o  {"ok": false, "mensaje": "..."}
-- (No lanza errores: así el contador de intentos fallidos sí se guarda.)
drop function if exists public.recuperar_clave(text, text, text);
create or replace function public.recuperar_clave(p_email text, p_codigo text, p_nueva text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_id uuid;
  v_fila public.codigos_recuperacion;
  v_codigo text := upper(regexp_replace(coalesce(p_codigo, ''), '[^A-Za-z0-9]', '', 'g'));
  v_celular boolean := lower(p_email) like '%@vecinos.example.com';
  v_malo constant jsonb := jsonb_build_object('ok', false, 'mensaje', 'El número o el código no son correctos.');
begin
  select id into v_id from auth.users where email = lower(btrim(p_email));
  if v_id is null then
    return v_malo;
  end if;
  select * into v_fila from public.codigos_recuperacion where usuario = v_id;
  if v_fila.usuario is null then
    return v_malo;
  end if;
  if v_fila.bloqueado_hasta is not null and v_fila.bloqueado_hasta > now() then
    return jsonb_build_object('ok', false, 'mensaje', 'Demasiados intentos. Espera 15 minutos o pide ayuda a la junta vecinal.');
  end if;
  if crypt(v_codigo, v_fila.codigo_hash) <> v_fila.codigo_hash then
    update public.codigos_recuperacion
       set intentos = case when intentos + 1 >= 5 then 0 else intentos + 1 end,
           bloqueado_hasta = case when intentos + 1 >= 5 then now() + interval '15 minutes' else null end
     where usuario = v_id;
    return v_malo;
  end if;
  -- Mismas reglas de clave que la app.
  if v_celular and (p_nueva !~ '^[0-9]{6}$' or p_nueva ~ '^([0-9])\1{5}$'
                    or p_nueva in ('123456', '234567', '345678', '456789', '654321', '987654', '012345')) then
    return jsonb_build_object('ok', false, 'mensaje', 'La clave nueva debe tener 6 números y no ser fácil de adivinar.');
  end if;
  if not v_celular and (char_length(p_nueva) < 8 or p_nueva !~ '[A-Za-z]' or p_nueva !~ '[0-9]') then
    return jsonb_build_object('ok', false, 'mensaje', 'La contraseña nueva debe tener 8 o más caracteres, con letras y números.');
  end if;

  update auth.users
     set encrypted_password = crypt(p_nueva, gen_salt('bf')), updated_at = now()
   where id = v_id;
  -- El código usado ya no sirve: se entrega uno nuevo.
  return jsonb_build_object('ok', true, 'codigo', public._nuevo_codigo(v_id));
end $$;
grant execute on function public.recuperar_clave(text, text, text) to anon, authenticated;

-- La junta vecinal ayuda en persona a quien perdió su código.
create or replace function public.codigo_para_vecino(p_celular text) returns text
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  if public.mi_rol() <> 'moderador' then
    raise exception 'Solo la junta vecinal puede hacer esto.' using errcode = 'P0001';
  end if;
  if p_celular !~ '^9[0-9]{8}$' then
    raise exception 'Escribe un celular de 9 dígitos que empiece con 9.' using errcode = 'P0001';
  end if;
  select id into v_id from auth.users where email = '51' || p_celular || '@vecinos.example.com';
  if v_id is null then
    raise exception 'No hay ninguna cuenta con ese celular.' using errcode = 'P0001';
  end if;
  return public._nuevo_codigo(v_id);
end $$;
grant execute on function public.codigo_para_vecino(text) to authenticated;

insert into public.migraciones (version, nombre)
values ('0015', 'recuperar_clave')
on conflict (version) do nothing;
