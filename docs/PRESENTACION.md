# App Vecinal · Material de presentación (AlphaCoders)

> Borrador para el equipo. Ajustar tiempos al formato oficial cuando lo confirme la organización.
> Supuesto: **7 minutos de exposición + preguntas**.

---

## 1. Estructura de diapositivas (10 láminas)

| # | Lámina | Contenido | Criterio que cubre |
|---|---|---|---|
| 1 | **Portada** | App Vecinal · "Tu barrio te respalda, con o sin internet". Equipo AlphaCoders, integrantes y roles. | Organización |
| 2 | **Propósito** | "Que cualquier vecino de Chimbote consiga ayuda confiable cerca de casa, a costo mínimo, y que el barrio se coordine solo en una emergencia." | Organización (propósito al inicio) |
| 3 | **Problema** | Buscar un gasfitero confiable = preguntar de boca en boca. Favores sin canal. En lluvias e inundaciones (ej. El Niño Costero 2017 en Áncash — *verificar el dato y citar la fuente en la lámina*) la ayuda vecinal se coordina de boca en boca y la señal puede caerse. Adultos mayores fuera de las apps. | Propuesta |
| 4 | **Solución** | 2 módulos × 2 modos: Servicios de proximidad (Visto Bueno Vecinal) y Cadena de Favores, cada uno con versión día a día y emergencia. Captura de Inicio y de Emergencia lado a lado. | Código y programa |
| 5 | **Diferenciador 1 · Mula de datos QR** | Diagrama: Vecino sin señal → QR → Vecino que se mueve → Internet → Tablero del barrio. "La información viaja de persona a persona cuando la red se cae." | Innovación |
| 6 | **Diferenciador 2 · Accesible para todos** | Botón Escuchar, letra A/A+/A++, alto contraste, registro con celular (sin correo), publicar en 3 toques, interfaz 100 % en español. Foto de la app con letra grande. | Usabilidad |
| 7 | **Demo en vivo** | (ver guion abajo) | Confiabilidad, Usabilidad |
| 8 | **Arquitectura y escalabilidad** | Flutter (Android + web, un solo código) · Supabase (Postgres + Auth + RLS) · Offline-first (caché + cola con IDs del teléfono) · Seguridad en el servidor por rol. Diagrama de 3 cajas. | Escalabilidad, Código |
| 9 | **Riesgos y beneficios para la institución** | Tabla de la sección 4 de este documento. | Propuesta |
| 10 | **Roadmap y conclusiones** | Roadmap (sección 5). 3 conclusiones: confianza vecinal medible, ayuda que llega aunque caiga la red, nadie se queda fuera por edad o lectura. | Organización (conclusiones al cierre) |

**Recursos audiovisuales:** capturas reales del Honor, un diagrama de la mula QR, el mapa de Chimbote con pines, un gráfico simple "pasos para publicar: apps comunes 6–8 vs App Vecinal 3".

---

## 2. Guion de la demo (≈ 3 min, dentro de los 7)

Preparación antes de subir: Honor con letra normal, sesión de **moderador** iniciada, emergencia **apagada**, datos del `seed.sql` recién cargados, brillo al máximo, pantalla compartida por cable o cámara de documentos.

| Tiempo | Quién | Acción en la app | Qué se dice |
|---|---|---|---|
| 0:00 | Integrante 1 | Inicio → **Servicios** → ordenar "Recomendados" | "Doña Rosa necesita un gasfitero. No busca en Google: ve a quién recomiendan sus vecinos." |
| 0:20 | Integrante 1 | Abrir "Gasfitero a domicilio" → ver 5 Vistos Buenos → **Llamar** | "Cada Visto Bueno es de un vecino real; nadie puede recomendarse a sí mismo." |
| 0:40 | Integrante 2 | **Publicar** → "Pido un favor" → escribir "Necesito una escalera" → **Publicar ahora** | "Tres toques. Contamos: uno, dos, tres." (contar en voz alta) |
| 1:00 | Integrante 2 | Perfil → **A++** y **Alto contraste** → tocar **Escuchar** en una tarjeta | "Pensado para nuestros abuelos." |
| 1:20 | Integrante 3 | Perfil → Junta vecinal → **Activar modo emergencia** | "Lluvias en Chimbote. La junta activa la emergencia y la app de todo el barrio cambia." |
| 1:35 | Integrante 3 | Pantalla roja → **NECESITO AYUDA** → números 116/105/106 → tablero ordenado por urgencia | "Se puede pedir ayuda incluso sin cuenta." |
| 1:55 | Integrante 4 | Perfil → **Simular sin internet** → NECESITO AYUDA → publicar → **Mostrar QR** | "Se cayó la señal. El pedido no se pierde." |
| 2:20 | Integrante 4 | Segundo celular (con internet) → **Llevar mensajes** → escanear QR → "¡Pedido enviado!" | "Otro vecino lo lleva. Así la ayuda viaja de persona a persona." |
| 2:45 | Integrante 4 | Volver al tablero → el pedido aparece con etiqueta **LLEGÓ POR QR** | "Y la organización ya puede atenderlo." |
| 3:00 | Todos | Volver a láminas | — |

**Plan B:** grabar la demo completa en video antes de presentar (celular + grabación de pantalla). Si falla internet o el proyector, se reproduce el video.

---

## 3. Banco de preguntas probables

| Pregunta | Respuesta corta |
|---|---|
| ¿Cómo evitan recomendaciones falsas? | Un Visto Bueno por vecino y servicio, nadie puede recomendarse a sí mismo (regla en la base de datos), cuentas verificadas por GPS en la zona. Roadmap: validación por la junta. |
| ¿Qué pasa si no hay internet? | La app muestra la última información guardada; lo publicado queda en cola y se envía solo al volver la señal. Para urgencias, la mula de datos QR. |
| ¿Y si dos personas suben el mismo QR? | Cada pedido tiene un ID único generado en el teléfono; el servidor ignora duplicados. |
| ¿El que lleva el QR puede alterar el pedido? | No. El QR solo lleva campos de contenido (lista blanca), quien lo sube no queda como autor y no puede cambiar el estado. |
| ¿Quién activa la emergencia? ¿Y si nadie lo hace? | El moderador (junta vecinal). Roadmap: activación automática por volumen de reportes o alerta oficial. |
| ¿Cómo protegen datos personales? | El teléfono y la ubicación exacta del perfil no son públicos; la seguridad está en el servidor (RLS), no solo en la app. Solo se muestra el contacto que cada vecino decide publicar. |
| ¿Por qué no hay pagos? | El reto pide costo mínimo; el módulo 2 es sin dinero por diseño. El módulo 1 conecta, el acuerdo de pago es entre vecinos. |
| ¿Escala a otras ciudades? | La zona y sectores están en un solo archivo de configuración; el esquema es multi-zona agregando un campo de zona. Supabase escala horizontalmente. |
| ¿Por qué Flutter y Supabase? | Un solo código para Android y web; Supabase da base de datos, autenticación y seguridad por filas sin servidor propio, ideal para 48 h y bajo costo. |
| ¿Accesibilidad real? | Lectura en voz alta, 3 tamaños de letra, alto contraste, botones grandes, etiquetas para lector de pantalla, registro con celular, mapa también como lista. |
| ¿Cuánto cuesta operarlo? | Plan gratuito de Supabase para un barrio; mapas OpenStreetMap sin licencia. |

---

## 4. Riesgos y beneficios para la institución

| Riesgo | Mitigación |
|---|---|
| Recomendaciones falsas o spam | 1 Visto Bueno por vecino; verificación GPS; moderador puede eliminar contenido. |
| Mal uso del modo emergencia | Solo el moderador lo activa; confirmación doble en la app. |
| Pedidos de ayuda falsos sin cuenta | Solo se permiten con emergencia activa; organizaciones validan antes de atender. |
| Caída de internet en desastres | Offline-first + mula de datos QR. |
| Exclusión digital de adultos mayores | Voz, letra grande, alto contraste, registro con celular. |
| Privacidad | Datos sensibles protegidos por reglas en el servidor (RLS). |

**Beneficios:** dinamiza la economía local (oficios del barrio), reduce traslados y costos, fortalece la confianza vecinal, da a la municipalidad / Defensa Civil un tablero geolocalizado de necesidades en tiempo real, y es de bajo costo de operación.

---

## 5. Roadmap

1. Activación automática de emergencia (umbral de reportes / alerta oficial).
2. Verificación por código de la junta vecinal y validación entre vecinos.
3. Notificaciones push y chat interno.
4. Asistente con IA para recomendar a quién acudir.
5. Mula de datos en cadena por Bluetooth (sin necesidad de mostrar el QR).
6. Panel web para municipalidad y Defensa Civil.

---

## 6. Checklist del reto (B2)

- [x] Información recomendada de productos y servicios cercanos (Servicios + Visto Bueno + distancia)
- [x] Promover servicios y compartir recomendaciones (perfil prestador + Visto Bueno con comentario)
- [x] Solicitar y ofrecer ayuda e intercambios solidarios (Cadena de Favores)
- [x] Servicios y grupos de apoyo en emergencias (Módulo 1 emergencia)
- [x] Coordinación de necesidades y recursos en emergencia (tablero humanitario + recursos + atender/resolver)
- [x] Geolocalización (mapa + distancias + lista por cercanía)
- [x] Tutorial
- [x] Móvil y máximo 3 clics para publicar
- [x] Online y offline (+ QR)
- [x] Intuitivo y accesible
- [ ] Probar en vivo con un usuario real antes de presentar
- [ ] Grabar video de respaldo de la demo
- [ ] Ensayar con cronómetro
