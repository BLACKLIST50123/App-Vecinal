# Base de datos (Supabase) · Migraciones

La base de datos se construye con **migraciones numeradas**. Cada cambio nuevo va en un archivo nuevo, así **nunca hay que volver a ejecutar todo**.

```
supabase/
  migrations/
    0001_base.sql            perfiles, servicios, Visto Bueno, emergencia, publicaciones
    0002_coordinacion.sql    "Yo ayudo", Visto Bueno verificado, tiempo real
    0003_confianza.sql       reportes, verificación, estado "no verificado"
    0004_solidaridad.sql     colectas (meta y avance), respuestas
    0005_reconocimiento.sql  agradecimientos, ayudas confirmadas, niveles
    0006_sos.sql             modo SOS: reportes de un toque, con o sin cuenta
    0007_sos_seguro.sql      avisos reservados (secuestro, extorsión, violencia) y límite por cuenta
    0008_aportes_y_pedidos.sql  pedidos de servicio y "Mis aportes"
    0009_foro.sql            foro vecinal: temas, respuestas y reacciones
    0010_foto_perfil.sql     foto de perfil (Storage "avatares")
    0011_brigadistas.sql     la junta nombra brigadistas de su sector; canales del sector
    0012_estoy_bien.sql      "Estoy bien / Necesito ayuda" en emergencia y conteo para la junta
  seed.sql                   datos de demostración (se puede repetir)
```

## Cómo usarlas

**Proyecto nuevo:** ejecuta en orden, en **SQL Editor**: `0001`, `0002`, `0003`, `0004`, `0005`… y al final `seed.sql`.

**Proyecto que ya existe:** revisa qué tienes aplicado y ejecuta **solo las que faltan**:

```sql
select version, nombre, aplicada_en from public.migraciones order by version;
```

Si la tabla `migraciones` no existe, tu proyecto se creó con el antiguo `schema.sql` (equivale a 0001–0003). Ejecuta desde la `0004`.

## Reglas para el equipo

1. **Nunca edites una migración que ya se aplicó.** Crea la siguiente (`0006_...sql`).
2. Cada migración debe poder repetirse sin error (`if not exists`, `drop policy if exists`, `on conflict do nothing`).
3. Al final de cada archivo, regístrala: `insert into public.migraciones (version, nombre) values ('0006', '...') on conflict do nothing;`
4. Solo **BE1** crea migraciones (ver `docs/EQUIPO.md`).

> Roadmap: pasar a la **Supabase CLI** (`supabase migration new` / `supabase db push`) para aplicarlas automáticamente desde Git.

## Roles de demo

Para convertir una cuenta en moderador u organización:

```sql
update public.perfiles set rol = 'moderador'      -- o 'organizacion'
where id = (select id from auth.users where email = '51987654321@vecinos.example.com');
```

Las cuentas creadas con celular usan internamente el correo `51<número>@vecinos.example.com`.
