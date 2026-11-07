# App Vecinal · Reparto de responsabilidades (2 frontend + 3 backend)

> Entrega: **sábado 8 nov, 7:00 p. m.** · **Congelamiento de código: sábado 8 nov, 12:00 m.**
> Después del congelamiento solo se corrigen errores; la tarde es para video, ensayo y presentación.

## Reglas para no pisarnos

1. **Cada rol es dueño de sus archivos** (columna "Archivos"). Si necesitas tocar el archivo de otro, avísale primero.
2. **Una rama por tarea**: `fe1/identidad-visual`, `be2/sms`, etc. Nada directo a `main`.
3. **Pull Request pequeño** y que otro integrante lo revise antes de unir. Antes de abrirlo: `flutter analyze` sin errores y `flutter test` en verde.
4. **Base de datos**: solo **BE1** crea migraciones nuevas en `supabase/migrations/` (nunca edita una ya aplicada). Los demás le piden el cambio. Ver `supabase/README.md`.
5. **Credenciales**: `supabase.json` nunca se sube. La URL y la key se pasan por privado.
6. Cada 3 horas, **5 minutos de sincronización**: qué terminé, qué sigue y qué me bloquea.

---

## FE1 · Frontend: identidad visual y experiencia (UI)

**Objetivo:** que la app se vea profesional, cálida y minimalista. Que no parezca una app "básica".

| # | Tarea | Detalle | Prioridad |
|---|---|---|---|
| 1 | Ícono y pantalla de carga | `flutter_launcher_icons` y `flutter_native_splash`, con el logo de App Vecinal. | Alta |
| 2 | Tipografía | Fuente legible y cálida (Nunito o Atkinson Hyperlegible) **incluida como asset**, no descargada, para que funcione sin internet. | Alta |
| 3 | Paleta y tema | Revisar `tema.dart`: colores del día a día, de emergencia y de alto contraste. El contraste mínimo debe ser AA (4.5:1). | Alta |
| 4 | Inicio rediseñado | Encabezado con saludo e identidad visual, **buscador arriba**, accesos grandes y secciones "cerca de ti". | Alta |
| 5 | Tarjetas | Avatar con iniciales y color por categoría, jerarquía clara (qué → quién → dónde) y menos texto gris. | Media |
| 6 | Microanimaciones | `flutter_animate`: entrada de tarjetas, botón Publicar y cambio a modo emergencia. Sutiles, sin marear. | Media |
| 7 | Pantalla "¡Publicado!" | Confirmación visual con animación, en lugar de solo un mensaje abajo. | Media |
| 8 | Capturas para la presentación | Capturas limpias del Honor para las láminas: inicio, emergencia, QR y accesibilidad. | Alta (sábado) |

**Archivos:** `lib/ui/tema.dart`, `lib/ui/widgets.dart`, `lib/screens/inicio.dart`, `lib/screens/home_shell.dart`, `assets/`, `pubspec.yaml` (solo assets e íconos).
**Entregable:** la misma app, con identidad propia y las capturas listas.

---

## FE2 · Frontend: accesibilidad, voz y flujos

**Objetivo:** que **cualquier vecino**, incluso un adulto mayor, publique en 3 toques **o hablando**.

| # | Tarea | Detalle | Prioridad |
|---|---|---|---|
| 1 | **Publicar por voz** (diferenciador) | `speech_to_text` (reconocimiento del propio celular, costo cero). Botón de micrófono grande en el formulario: el vecino dice "necesito una escalera" y se llena el título. | Alta |
| 2 | Categoría automática | Sugerir la categoría según palabras clave del texto (agua → Agua y alimentos, gasfitero → Gasfitería). Sin IA de pago. | Alta |
| 3 | Auditoría con TalkBack | Recorrer los flujos principales con el lector de pantalla del Honor y corregir etiquetas, orden y botones sin nombre. | Alta |
| 4 | Verificar los "3 toques" | Contar los toques en cada tipo de publicación y quitar pasos que sobren. | Alta |
| 5 | Mensajes y estados vacíos | Revisar textos: lenguaje simple, sin tecnicismos, en tú. | Media |
| 6 | Versión web responsiva | Que el panel de coordinación y las listas se vean bien en laptop (ancho máximo y 2 columnas). | Media |
| 7 | Prueba con vecinos | Acompañar a BE3 en la prueba observada y anotar dónde dudan. | Alta |

**Archivos:** `lib/screens/publicar.dart`, `lib/screens/tutorial.dart`, `lib/screens/auth_screen.dart`, `lib/services/voz.dart`, `lib/screens/listas.dart`.
**Entregable:** publicar por voz funcionando en el Honor y el informe de la auditoría de accesibilidad.

---

## BE1 · Backend: base de datos, seguridad y roles (Supabase)

**Objetivo:** que los datos sean confiables y seguros, y que el modelo soporte crecer (escalabilidad).

| # | Tarea | Detalle | Prioridad |
|---|---|---|---|
| 1 | Auditoría de RLS | Probar cada política con las 4 cuentas (visitante, vecino, organización y moderador). Anotar qué puede y qué no puede hacer cada una. | Alta |
| 2 | Anti-spam | Trigger: máximo N publicaciones por hora por cuenta y un límite para las publicaciones sin cuenta. | Alta |
| 3 | Cuentas de demo | Crear 4 cuentas de prueba con su rol: moderador, organización y 2 vecinos. Guardar los datos en un lugar privado del equipo. | Alta |
| 4 | Índices y rendimiento | Índices por `created_at`, sector y estado. Revisar el plan de las consultas del tablero. | Media |
| 5 | Datos de demo realistas | Mejorar `seed.sql` con más oficios y productos reales de un sector piloto, con permiso de las personas. | Media |
| 6 | Multi-zona (escalabilidad) | Diseñar (aunque no se implemente) una columna `zona` para escalar a otras ciudades, y explicarlo en la lámina de arquitectura. | Baja |
| 7 | Respaldo | Exportar un respaldo de la base antes de la demo y tener lista la forma de reiniciar los datos. | Alta (sábado) |

**Archivos:** `supabase/migrations/`, `supabase/seed.sql` (dueño único).
**Entregable:** matriz de permisos por rol (sirve para responder al jurado), anti-spam activo y cuentas de demo.

---

## BE2 · Backend: offline, sincronización y canales alternativos

**Objetivo:** que la ayuda **llegue aunque no haya internet**. Es el diferenciador técnico del equipo.

| # | Tarea | Detalle | Prioridad |
|---|---|---|---|
| 1 | **Pedido por SMS** (diferenciador) | Botón "Enviar por SMS" en pedidos sin conexión: abre la app de SMS con el texto listo (`sms:`) para un número de la junta o de un familiar. Funciona con saldo, sin datos. | Alta |
| 2 | Primer uso sin internet | Incluir en la app un `assets/demo.json` con información básica (números de emergencia, grupos de apoyo y normas) para que la app no aparezca vacía si se abre por primera vez sin señal. | Alta |
| 3 | Pruebas de la mula QR | Probar con 2 celulares: QR repetido, QR de una app distinta, escanear sin internet, varios QR seguidos. | Alta |
| 4 | Robustez de la cola | Qué pasa si se cierra la app con publicaciones pendientes, si cambia la cuenta o si falla el servidor. Agregar reintentos. | Media |
| 5 | Tiempo real | Verificar que la emergencia y los pedidos lleguen al instante y que se reconecte después de perder la señal. | Media |
| 6 | Pruebas automáticas | Más pruebas en `test/` para la cola y para el decodificador de QR. | Media |

**Archivos:** `lib/data/repo.dart`, `lib/data/qr_codec.dart`, `lib/screens/qr_screens.dart`, `lib/state/app_state.dart`, `test/`.
**Entregable:** SMS funcionando, informe de pruebas de la mula QR y app usable al primer uso sin señal.

---

## BE3 · Backend: despliegue, métricas y validación (DevOps + datos)

**Objetivo:** que la demo **no falle** y que el equipo llegue con **evidencia**.

| # | Tarea | Detalle | Prioridad |
|---|---|---|---|
| 1 | Publicar versión web | Netlify Drop (`flutter build web --release`) con un link fijo para el jurado y el equipo. | Alta |
| 2 | APK release | Compilar y repartir el APK a todo el equipo. Instalarlo en un **segundo celular** para la demo de QR. | Alta |
| 3 | Validación con vecinos | Coordinar entrevistas y la prueba observada con 8 a 10 vecinos (ver `docs/PRESENTACION.md` §7). Tabular los resultados. | **Muy alta** |
| 4 | Indicadores | Llevar a las láminas las métricas del panel y de la validación: % que publicó sin ayuda y tiempo promedio. | Alta |
| 5 | Verificar fuentes | Confirmar cada cifra de la matriz de evidencia en su fuente original. | Alta |
| 6 | Video de respaldo | Grabar la demo completa en el Honor después del congelamiento. | Alta (sábado) |
| 7 | README y documentación | Mantener `README.md` y `docs/` al día y ordenados para el jurado. | Media |

**Archivos:** `README.md`, `docs/`, carpeta de builds (no se sube a Git).
**Entregable:** link web, APK en 2 celulares, resultados de la validación y video de respaldo.

---

## Cronograma sugerido

| Bloque | FE1 | FE2 | BE1 | BE2 | BE3 |
|---|---|---|---|---|---|
| **Vie tarde** | Ícono, splash, fuente | Voz + categoría automática | Auditoría RLS + cuentas demo | SMS + `demo.json` | Web + APK + agendar vecinos |
| **Vie noche** | Inicio y tarjetas | TalkBack + 3 toques | Anti-spam + índices | Pruebas QR (2 celulares) | Validación con vecinos |
| **Sáb mañana** | Animaciones + "¡Publicado!" | Pulir textos + web responsiva | Respaldo + reinicio de datos | Robustez de la cola + tests | Tabular resultados + fuentes |
| **Sáb 12:00** | 🔒 **Congelamiento de código**: unir a `main`, compilar APK y web finales | | | | |
| **Sáb tarde** | Capturas para láminas | Ensayo de demo | Soporte técnico en la demo | Celular 2 listo para QR | Video de respaldo + ensayo |

## Roles en la presentación (sugerido)

| Integrante | Parte del guion |
|---|---|
| FE1 | Propósito, problema e identidad (láminas 1 a 3) |
| FE2 | Demo: publicar en 3 toques, voz y accesibilidad |
| BE1 | Arquitectura, seguridad y roles (láminas 8 y 9) |
| BE2 | Demo: emergencia sin internet, QR y SMS |
| BE3 | Evidencia, validación, roadmap y conclusiones (láminas 9 y 10) |
