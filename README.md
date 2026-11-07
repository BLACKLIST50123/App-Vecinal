# App Vecinal · Chimbote

App móvil para obtener **productos y servicios recomendados por vecinos**, con **intercambios solidarios** y un **modo emergencia** para coordinar ayuda en el barrio, incluso **sin internet**.

Equipo **AlphaCoders** · Hackathon UTP 2026 · Flutter (Android + web) + Supabase.

## Funcionalidades

| Reto | En la app |
|---|---|
| Servicios de proximidad (día a día) | Directorio de oficios con **Visto Bueno Vecinal** (1 por vecino, no a uno mismo). Búsqueda, filtro por oficio, orden por recomendaciones o cercanía, llamar / WhatsApp. |
| Servicios de proximidad (emergencia) | Directorio de **grupos de apoyo** publicados por organizaciones verificadas. |
| Cadena de favores (día a día) | Muro **sin dinero**: herramientas, ayuda temporal, donaciones, habilidades, movilidad solidaria. |
| Red de solidaridad (emergencia) | **Tablero humanitario** ordenado por urgencia, reportes de **vecinos vulnerables** y **recursos críticos**. |
| Modo emergencia | Lo activa el moderador; toda la app cambia a rojo, botón **NECESITO AYUDA** y números 116 / 105 / 106. |
| Pedir ayuda sin cuenta | Permitido solo con emergencia activa (controlado en el servidor con RLS). |
| Geolocalización | Mapa OpenStreetMap con pines por tipo y vista **"como lista"** ordenada por distancia. |
| Máximo 3 clics para publicar | **Publicar → tipo → Publicar ahora** (ubicación, categoría y contacto precargados). |
| Online y offline | Caché de lecturas + **cola de envío**; IDs generados en el teléfono para no duplicar. |
| Tutorial | 5 pasos al primer ingreso, con voz y selector de tamaño de letra. |

### Diferenciadores

- **Mula de datos por QR.** Sin señal, tu pedido se guarda y se muestra como código QR. Otro vecino lo escanea (también sin señal) y su app lo publica cuando recupera internet. Quien lo transporta no queda como autor y el pedido no se duplica aunque lo escaneen varios.
- **Accesibilidad total.** Botón **Escuchar** (lectura en voz alta) en todo el contenido, letra A / A+ / A++, alto contraste, botones de 52 px o más, etiquetas para lector de pantalla, interfaz en español.

## Roles

| Rol | Puede |
|---|---|
| Visitante | Ver todo. En emergencia, pedir ayuda sin cuenta. |
| Vecino | Publicar favores y servicios (perfil prestador opcional), dar Visto Bueno. Verificado por GPS al registrarse. |
| Organización de apoyo | Publicar grupos de apoyo y atender reportes de emergencia. |
| Moderador (junta vecinal) | Activar y terminar el modo emergencia. |

## Arquitectura

```
lib/
  main.dart            arranque, tema y escala de texto
  config.dart          zona (Chimbote), sectores y categorías
  models.dart          Servicio, Publicacion, VistoBueno, EstadoEmergencia
  data/repo.dart       Supabase + caché offline + cola de envío
  data/qr_codec.dart   mula de datos (lista blanca de campos)
  state/app_state.dart sesión, rol, emergencia, conexión, accesibilidad
  services/            GPS y lectura en voz alta
  screens/             inicio, emergencia, servicios, favores, mapa, publicar, QR, perfil, tutorial
  ui/                  tema accesible y componentes
supabase/
  migrations/          migraciones numeradas 0001…: tablas, triggers y políticas RLS por rol
  seed.sql             datos de demostración de Chimbote
```

La seguridad vive en el servidor (RLS): el nombre y rol del autor los pone un trigger, nadie puede cambiarse el rol, el teléfono y la ubicación exacta de los perfiles no son públicos, y la verificación GPS se calcula en la base de datos.

## Cómo ejecutarlo

1. En Supabase > SQL Editor ejecuta en orden las migraciones de `supabase/migrations/` (0001, 0002…) y luego `supabase/seed.sql`. Ver `supabase/README.md`.
2. En Authentication > Email desactiva "Confirm email" (para la demo).
3. Copia `supabase.example.json` como `supabase.json` y pon tu Project URL y publishable key (este archivo no se sube a Git).
4. Ejecuta:

```bash
flutter pub get
flutter run -d chrome --dart-define-from-file=supabase.json
```

En VS Code basta con **F5** (configuraciones en `.vscode/launch.json`).

Para volver moderador a una cuenta:

```sql
update public.perfiles set rol = 'moderador'
where id = (select id from auth.users where email = 'correo@ejemplo.com');
```

## Roadmap

- Activación automática de la emergencia por cantidad de reportes o alerta oficial (INDECI).
- Verificación por código de la junta vecinal y validación entre vecinos.
- Notificaciones push y mensajería interna.
- Asistente con IA para recomendar a quién acudir.
- Transporte de QR en cadena (malla de vecinos) y Bluetooth.
