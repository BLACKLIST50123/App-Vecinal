# Modo SOS · Decisiones y evidencia

> Aprobado por el equipo. Cifras tomadas de fuentes públicas: **verificar en el PDF oficial antes de ponerlas en una lámina** (la prensa no siempre coincide).

## 1. Qué emergencias incluye y por qué (a nivel nacional)

La app debe servir en **cualquier ciudad del Perú**, no solo en la zona de la demo. Por eso las categorías del SOS se eligieron según las emergencias más frecuentes en barrios del país.

| Tarjeta | Evidencia | Prioridad |
|---|---|---|
| 🩺 **Emergencia médica** | ≈ 40 % de las emergencias que atienden los Bomberos (cálculo propio con 18 636 emergencias en 100 días de 2022: 7 380 médicas) | Muy urgente |
| 🛡️ **Inseguridad** → Robo · Extorsión · Secuestro · Violencia | Robo: más del 60 % de la victimización urbana es robo o intento de robo de objetos personales (IEP sobre INEI 2024). Extorsión: 22 361 denuncias en 2024 y 26 585 en 2025 (PNP, citado por el INEI); hasta 69 denuncias diarias en 2025 | Muy urgente (extorsión: urgente) |
| 🌊 **Lluvia, inundación o huaico** | Lluvias intensas (24 %) e inundaciones (11,7 %) = 35,7 % de las afectaciones 2003–2024 (INDECI vía IEP). Dic-2024 a mar-2025: más de 3 500 de 5 430 emergencias por lluvias (COEN-INDECI) | Muy urgente |
| 🔥 **Incendio o fuga de gas** | Incendios ≈ 15 % y fugas de gas licuado ≈ 9 % de las emergencias de Bomberos (mismo cálculo de 2022) | Muy urgente |
| 🚗 **Accidente de tránsito** | ≈ 18 % de las emergencias de Bomberos (mismo cálculo de 2022) | Muy urgente |
| 🏠 **Sismo** | Todo el litoral peruano es zona sísmica: poco frecuente, impacto muy alto | Muy urgente |
| ~~Falta de agua~~ | Retirada: es un problema de servicio, no un riesgo de vida inmediato | — |

**Escalabilidad:** ninguna categoría depende de una ciudad. Los números de emergencia son nacionales (105 Policía, 106 SAMU, 116 Bomberos). La ciudad es solo configuración (`lib/config.dart` y `en_zona()`); el siguiente paso es una columna `zona` para varias ciudades (roadmap).

## 2. Seguridad de quien pide ayuda

| Riesgo | Medida |
|---|---|
| El agresor ve el aviso (extorsión, secuestro, violencia) | **Aviso reservado**: solo lo ven quien lo envió, la junta (moderador) y las organizaciones de apoyo. Lo aplica el servidor (RLS, migración 0007). Sin vibración. |
| Exponer dónde vive la víctima | Ubicación aproximada (±200 m); la dirección exacta se coordina por teléfono. |
| Reacciones peligrosas | Consejo inmediato por tipo (ej. extorsión: "No pagues ni negocies, guarda los mensajes y denuncia al 105"; robo: "No te enfrentes"). |
| Depender solo de la app | Siempre visibles: 105 (Policía), 106 (SAMU), 116 (Bomberos). |

## 3. Alertas falsas o "continuas"

| Problema | Medida |
|---|---|
| Toque por error | 3 segundos para cancelar antes de enviar. |
| Spam sin cuenta | Máximo 3 SOS por zona (≈ 200 m) cada 10 minutos (0006). |
| Spam con cuenta | Máximo 3 SOS por cuenta cada 10 minutos (0007). |
| Alerta falsa publicada | Botón Reportar; con 3 reportes pasa a "sin confirmar" y sale de la lista. Las organizaciones pueden marcarla "no verificada". |
| Alerta que queda abierta para siempre | Vence sola: 24 h las muy urgentes, 6 h las demás. Quien la envió puede cerrarla con "Ya estoy bien / Fue un error". |

## 4. Cómo llega a los vecinos cercanos

- **En tiempo real:** al entrar un SOS a **menos de 2 km**, los vecinos con la app abierta reciben un aviso rojo arriba, con vibración y el botón "Ver y ayudar".
- **Franja "Alertas SOS activas"** en Inicio, Solidaridad y el Panel de coordinación (el brigadista las ve en su panel).
- **Límite:** con la app cerrada no llega. Requiere notificaciones push (Firebase Cloud Messaging) → **roadmap**.
- **Atajo de volumen:** con la app abierta, 3 toques abren el SOS. Con pantalla apagada requiere un servicio nativo → **roadmap**.

## Fuentes

- IEP · La victimización en el Perú: https://criticaydebate.iep.org.pe/noticias/la-victimizacion-en-el-peru-puede-un-indicador-desviar-el-rumbo-de-la-politica-de-seguridad/
- INEI · Seguridad ciudadana jul–dic 2025: https://www.inei.gob.pe/media/MenuRecursivo/boletines/seguridad_ciudadana_jul_dic_2025.pdf
- IEP · Afectación y percepción sobre emergencias (2026): https://estudiosdeopinion.iep.org.pe/wp-content/uploads/2026/08/IEP.-Informe-Afectacion-y-percepcion-sobre-emergencias-agosto-2026v2.pdf
- Andina · COEN-INDECI, emergencias por lluvias: https://andina.pe/agencia/noticia-coen-–-indeci-reporta-3603-emergencias-causadas-directamente-lluvias-intensas-1023104.aspx
- Panamericana · 18 000 emergencias de Bomberos en 100 días: https://panamericana.pe/nacionales/363567-100-dias-bomberos-atendieron-18-000-emergencias-pais
- Exitosa · Jefe del INEI, denuncias de extorsión 2025: https://www.exitosanoticias.pe/actualidad/jefe-inei-2025-registraron-mas-26-mil-denuncias-extorsion-n167302
- El Tiempo · de 10 a 69 denuncias diarias: https://eltiempo.pe/nacional/delito-en-peru-crecio-700-de-10-denuncias-diarias-en-2019-a-69-en-2025/
