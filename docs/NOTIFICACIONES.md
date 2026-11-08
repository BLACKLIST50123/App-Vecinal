# Plan: sistema de notificaciones

## Objetivo
Que cada vecino elija qué avisos recibe, con las **emergencias** como prioridad,
y que la app lo guíe a activarlos con un **puntito rojo en Perfil**.

## Tipos de aviso

| Aviso | Por defecto | Prioridad | Cuándo llega |
|---|---|---|---|
| Modo emergencia del barrio | Encendido | Crítica | La junta activa o termina una emergencia |
| Alertas SOS cerca de ti | Encendido | Crítica | Un SOS nuevo a ≤ 2 km (que no es tuyo) |
| Pedidos de ayuda en tu barrio | Encendido | Normal | Un pedido de ayuda nuevo (no SOS, no tuyo) |
| Pedidos a mis servicios | Encendido | Normal | Alguien pide un servicio tuyo |
| Novedades del foro | Apagado | Normal | Un tema nuevo en el foro |

Las críticas usan un canal de Android de importancia máxima ("Emergencias y SOS").
Apagar una crítica pide confirmación ("te recomendamos dejarlo encendido").

## Recordatorio (puntito rojo)
Se muestra en el ícono de **Perfil** de la barra inferior, en una tarjeta guía
arriba del perfil y en la fila **Ajustes → Notificaciones**, mientras:
- el vecino no haya tocado "Activar notificaciones", o
- el celular bloquee los avisos (permiso negado), o
- tenga apagado algún aviso de emergencia.

## Avisos con la app abierta o en segundo plano
- `lib/services/notificaciones.dart`: tipos de aviso y avisos del sistema
  (`flutter_local_notifications`, solo Android; en web se usan mensajes en pantalla).
- `AppState`: preferencias guardadas en el teléfono (`shared_preferences`),
  `activarAvisos()`, `setAviso()`, `notificar()` y `faltaActivarAvisos`.
- Los eventos llegan por Supabase Realtime (emergencia, publicaciones,
  pedidos_servicio y foro_temas). Con la app en pantalla se muestra un mensaje;
  en segundo plano, un aviso en la barra del celular.
- `lib/screens/notificaciones_screen.dart`: pantalla para activar y elegir.
- Android: permiso `POST_NOTIFICATIONS` y desugaring en Gradle.

## Avisos con la app cerrada: push con Firebase (activo)

### Cómo funciona
1. La app obtiene el **token FCM** del celular (`lib/services/push.dart`) y lo
   guarda con sus preferencias llamando a `registrar_dispositivo()`.
2. Al pasar algo (emergencia, SOS, pedido, pedido a servicio, tema del foro), un
   **disparador** en Postgres llama a la Edge Function `enviar-avisos`.
3. La función elige a quién avisar (preferencias, distancia ≤ 2 km para SOS,
   SOS reservados solo a brigadistas activos / coordinadores) y envía el push con
   **FCM v1**. Android lo muestra aunque la app esté cerrada.
4. Si el push está activo, la app ya no repite el aviso local (no hay duplicados).

Sin claves de Firebase (por ejemplo en web) solo hay avisos locales mientras la app esté viva.
Las claves van en `supabase.json` (FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_SENDER_ID, FIREBASE_PROJECT_ID), que no se sube a Git.

### Pasos para activarlo (una sola vez)
**Firebase**
1. Crear proyecto en https://console.firebase.google.com y agregar una app
   **Android** con paquete `com.alphacoders.appvecinal`.
2. En *Configuración del proyecto → General*, copiar a `supabase.json`:
   `FIREBASE_API_KEY` (Web API Key), `FIREBASE_APP_ID` (ID de la app Android),
   `FIREBASE_SENDER_ID` (Sender ID) y `FIREBASE_PROJECT_ID`.
3. En *Cuentas de servicio → Generar nueva clave privada*, descargar el JSON
   (¡no subirlo a Git!).

**Supabase**
1. *Database → Extensions*: activar **pg_net**.
2. *SQL Editor*: ejecutar `supabase/migrations/0012_notificaciones_push.sql`.
3. Desplegar la función:
   `supabase functions deploy enviar-avisos --no-verify-jwt`
4. *Edge Functions → Secrets*:
   - `FIREBASE_SERVICE_ACCOUNT` = contenido completo del JSON de la cuenta de servicio
   - `WEBHOOK_SECRET` = una clave larga inventada
5. *SQL Editor* (con tus valores):
   ```sql
   insert into public.config_push (id, url, secreto) values
     (1, 'https://<PROYECTO>.supabase.co/functions/v1/enviar-avisos', '<LA_MISMA_WEBHOOK_SECRET>')
   on conflict (id) do update set url = excluded.url, secreto = excluded.secreto;
   ```

### Probar
Activar avisos en la app, cerrarla por completo y, desde el panel de la junta,
activar el modo emergencia: debe llegar "🚨 EMERGENCIA en tu barrio".
