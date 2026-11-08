-- =====================================================================
-- 0014 · Validaciones en el servidor
-- Las mismas reglas que valida la app (lib/util.dart), aplicadas en la
-- base de datos para que no se puedan saltar desde fuera de la app.
-- "not valid": no revisa los datos que ya existen (no rompe la demo),
-- pero sí todo lo que se inserte o modifique desde ahora.
-- Se puede ejecutar varias veces sin error.
-- =====================================================================

-- Celular peruano: 9 dígitos que empiezan en 9 (o vacío / sin dato).
create or replace function public.celular_valido(t text) returns boolean
language sql immutable as $$
  select t is null or t = '' or t ~ '^9[0-9]{8}$';
$$;

-- Agrega una restricción solo si todavía no existe.
create or replace function public._agregar_check(p_tabla text, p_nombre text, p_expr text)
returns void language plpgsql as $$
begin
  if not exists (select 1 from pg_constraint where conname = p_nombre) then
    execute format('alter table public.%I add constraint %I check (%s) not valid', p_tabla, p_nombre, p_expr);
  end if;
end $$;

-- Perfiles
select public._agregar_check('perfiles', 'perfiles_nombre_largo', 'char_length(btrim(nombre)) between 2 and 60');
select public._agregar_check('perfiles', 'perfiles_telefono_valido', 'public.celular_valido(telefono)');
select public._agregar_check('perfiles', 'perfiles_oficio_largo', 'oficio is null or char_length(oficio) <= 60');

-- Publicaciones (pedidos y ofrecimientos)
select public._agregar_check('publicaciones', 'publicaciones_titulo_con_letras', 'titulo ~ ''[[:alpha:]].*[[:alpha:]].*[[:alpha:]]''');
select public._agregar_check('publicaciones', 'publicaciones_contacto_nombre_largo', 'contacto_nombre is null or char_length(contacto_nombre) <= 60');
select public._agregar_check('publicaciones', 'publicaciones_contacto_telefono_valido', 'public.celular_valido(contacto_telefono)');

-- Servicios y productos
select public._agregar_check('servicios', 'servicios_titulo_con_letras', 'titulo ~ ''[[:alpha:]].*[[:alpha:]].*[[:alpha:]]''');
select public._agregar_check('servicios', 'servicios_telefono_valido', 'public.celular_valido(telefono)');
select public._agregar_check('servicios', 'servicios_horario_largo', 'horario is null or char_length(horario) <= 80');
select public._agregar_check('servicios', 'servicios_precio_largo', 'precio_ref is null or char_length(precio_ref) <= 20');

-- Pedidos de servicio
select public._agregar_check('pedidos_servicio', 'pedidos_cliente_nombre_largo', 'char_length(cliente_nombre) <= 60');
select public._agregar_check('pedidos_servicio', 'pedidos_cliente_telefono_valido', 'public.celular_valido(cliente_telefono)');
select public._agregar_check('pedidos_servicio', 'pedidos_fecha_largo', 'fecha_deseada is null or char_length(fecha_deseada) <= 60');

-- Foro
select public._agregar_check('foro_temas', 'foro_temas_titulo_largo', 'char_length(btrim(titulo)) between 5 and 150');
select public._agregar_check('foro_temas', 'foro_temas_contenido_largo', 'char_length(btrim(contenido)) between 2 and 1000');
select public._agregar_check('foro_respuestas', 'foro_respuestas_contenido_largo', 'char_length(btrim(contenido)) between 1 and 1000');
select public._agregar_check('foro_respuestas', 'foro_respuestas_telefono_valido', 'public.celular_valido(contacto_telefono)');
select public._agregar_check('foro_respuestas', 'foro_respuestas_nombre_comercial_largo', 'nombre_comercial is null or char_length(nombre_comercial) <= 60');

-- Aviso de emergencia (lo escribe la junta para todo el barrio)
select public._agregar_check('emergencia', 'emergencia_titulo_largo', 'titulo is null or char_length(titulo) <= 60');
select public._agregar_check('emergencia', 'emergencia_mensaje_largo', 'mensaje is null or char_length(mensaje) <= 300');

-- Anti-spam general: máximo 10 publicaciones por hora por cuenta.
create or replace function public.limitar_publicaciones() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.autor_id is not null and (
    select count(*) from public.publicaciones p
     where p.autor_id = new.autor_id and p.created_at > now() - interval '1 hour'
  ) >= 10 then
    raise exception 'Publicaste muchas veces en poco tiempo. Espera un rato e inténtalo de nuevo.'
      using errcode = 'P0001';
  end if;
  return new;
end $$;

drop trigger if exists publicaciones_limite on public.publicaciones;
create trigger publicaciones_limite before insert on public.publicaciones
  for each row execute function public.limitar_publicaciones();

insert into public.migraciones (version, nombre)
values ('0014', 'validaciones')
on conflict (version) do nothing;
