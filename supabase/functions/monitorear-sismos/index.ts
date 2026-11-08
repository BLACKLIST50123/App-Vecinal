// Edge Function: monitorear-sismos
// Consulta sismos recientes en el área de Perú (vía USGS API o llamada manual de prueba),
// calcula el radio dinámico de afectación y guarda el sismo en `public.sismos`.
// La base de datos se encarga de disparar el push y activar el Modo Emergencia en la zona.
//
// Desplegar:  supabase functions deploy monitorear-sismos --no-verify-jwt

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

function calcularRadioAlerta(magnitud: number): number {
  if (magnitud < 4.0) return 30;   // Micro/leve (ej. 3.8) -> 30 km
  if (magnitud < 4.5) return 50;   // Perceptible moderado -> 50 km
  if (magnitud < 5.5) return 100;  // Fuerte -> 100 km (abarca Chimbote + Nuevo Chimbote + alrededores)
  if (magnitud < 6.5) return 200;  // Muy Fuerte -> 200 km
  return 400;                      // Terremoto mayor -> 400+ km
}

Deno.serve(async (req) => {
  try {
    // Si la llamada es POST con datos de prueba, permite simular un sismo directamente
    if (req.method === "POST") {
      const cuerpo = await req.json().catch(() => ({}));
      if (cuerpo && cuerpo.magnitud && cuerpo.lat && cuerpo.lng) {
        const mag = Number(cuerpo.magnitud);
        const radio = calcularRadioAlerta(mag);
        const id = cuerpo.id || `sim_${Date.now()}`;
        const sismo = {
          id,
          fecha_hora: cuerpo.fecha_hora || new Date().toISOString(),
          magnitud: mag,
          profundidad_km: Number(cuerpo.profundidad_km || 30),
          ubicacion: String(cuerpo.ubicacion || "Zona costera"),
          lat: Number(cuerpo.lat),
          lng: Number(cuerpo.lng),
          intensidad: cuerpo.intensidad || null,
          radio_alerta_km: radio,
          activo_emergencia: mag >= 4.5,
          notificado: false,
        };

        const { error } = await db.from("sismos").upsert(sismo);
        if (error) throw error;
        return Response.json({ ok: true, sismo, simulado: true });
      }
    }

    // Consulta automática a la API pública de sismos (USGS en bounding box de Perú)
    // Coordenadas aproximadas de Perú: Lat (-18.5 a 0.0), Lng (-81.5 a -68.5)
    const ahora = new Date();
    const haceDosHoras = new Date(ahora.getTime() - 2 * 60 * 60 * 1000).toISOString();
    const url = `https://earthquake.usgs.gov/fdsnws/event/1/query?format=geojson&starttime=${haceDosHoras}&minmagnitude=3.8&minlatitude=-18.5&maxlatitude=-0.0&minlongitude=-81.5&maxlongitude=-68.5`;

    const res = await fetch(url);
    if (!res.ok) {
      return new Response(`Error consultando USGS: ${res.statusText}`, { status: 502 });
    }

    const data = await res.json();
    const features = data.features || [];
    let nuevos = 0;

    for (const f of features) {
      const id = f.id;
      const mag = f.properties.mag;
      const place = f.properties.place || "Perú";
      const time = new Date(f.properties.time).toISOString();
      const [lng, lat, profundidad] = f.geometry.coordinates;

      const radio = calcularRadioAlerta(mag);

      // Verificamos si ya existe para no duplicar
      const { data: existente } = await db.from("sismos").select("id").eq("id", id).maybeSingle();
      if (!existente) {
        await db.from("sismos").insert({
          id,
          fecha_hora: time,
          magnitud: mag,
          profundidad_km: profundidad || 0,
          ubicacion: place,
          lat,
          lng,
          radio_alerta_km: radio,
          activo_emergencia: mag >= 4.5,
          notificado: false,
        });
        nuevos++;
      }
    }

    return Response.json({ ok: true, sismos_revisados: features.length, nuevos_insertados: nuevos });
  } catch (err) {
    console.error(err);
    return new Response(String(err), { status: 500 });
  }
});
