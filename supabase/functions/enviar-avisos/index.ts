// Edge Function: enviar-avisos
// La llaman los disparadores de la migración 0010 (emergencia, SOS, pedidos,
// pedidos a servicios y foro). Busca qué celulares tienen ese aviso
// encendido y les manda un push con Firebase Cloud Messaging (FCM v1),
// que llega aunque la app esté cerrada.
//
// Secretos (Edge Functions > Secrets):
//   WEBHOOK_SECRET            misma clave que config_push.secreto
//   FIREBASE_SERVICE_ACCOUNT  JSON de la cuenta de servicio de Firebase
// SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY los pone Supabase solo.
//
// Desplegar:  supabase functions deploy enviar-avisos --no-verify-jwt

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

type Fila = Record<string, unknown>;
type Dispositivo = { token: string; usuario_id: string | null; lat: number | null; lng: number | null };

const RADIO_SOS_KM = 2;

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

Deno.serve(async (req) => {
  if (req.headers.get("x-webhook-secret") !== Deno.env.get("WEBHOOK_SECRET")) {
    return new Response("no autorizado", { status: 401 });
  }
  try {
    const { tipo, registro } = (await req.json()) as { tipo: string; registro: Fila };
    const aviso = await armarAviso(tipo, registro);
    if (!aviso) return Response.json({ enviados: 0 });
    const tokens = aviso.destinos.map((d) => d.token);
    const enviados = await enviarATodos(tokens, aviso.titulo, aviso.cuerpo, aviso.critico, tipo);
    return Response.json({ enviados });
  } catch (e) {
    console.error(e);
    return new Response(String(e), { status: 500 });
  }
});

// --------------------------------------------------------- a quién avisar

async function armarAviso(tipo: string, r: Fila) {
  const autor = (r.autor_id ?? r.cliente_id ?? null) as string | null;
  const sinAutor = (lista: Dispositivo[]) => lista.filter((d) => !autor || d.usuario_id !== autor);

  if (tipo === "emergencia") {
    const destinos = await dispositivos("emergencia");
    return r.activa
      ? { destinos, critico: true, titulo: "🚨 EMERGENCIA en tu barrio", cuerpo: String(r.titulo ?? "La junta vecinal activó el modo emergencia.") }
      : { destinos, critico: true, titulo: "Terminó la emergencia", cuerpo: "Tu barrio volvió a la normalidad." };
  }

  if (tipo === "sos") {
    const lat = r.lat as number | null, lng = r.lng as number | null;
    let destinos = sinAutor(await dispositivos("sos_cercano"));
    // SOS reservado: solo brigadistas activos y coordinadores lo reciben.
    if (r.visibilidad === "restringida") {
      const permitidos = await coordinadores();
      destinos = destinos.filter((d) => d.usuario_id && permitidos.has(d.usuario_id));
      return { destinos, critico: true, titulo: "🆘 Alerta SOS reservada", cuerpo: "Un vecino necesita ayuda. Abre la app para ver el detalle." };
    }
    if (lat != null && lng != null) {
      destinos = destinos.filter((d) => d.lat == null || d.lng == null || distanciaKm(lat, lng, d.lat, d.lng) <= RADIO_SOS_KM);
    }
    return { destinos, critico: true, titulo: "🆘 SOS cerca de ti", cuerpo: String(r.titulo ?? "Un vecino pidió ayuda urgente.") };
  }

  if (tipo === "pedido_ayuda") {
    if (r.visibilidad === "restringida") return null;
    const destinos = sinAutor(await dispositivos("pedidos_ayuda"));
    return { destinos, critico: false, titulo: "Un vecino necesita una mano", cuerpo: String(r.titulo ?? "") };
  }

  if (tipo === "pedido_servicio") {
    const { data } = await db.from("dispositivos").select("token, usuario_id, lat, lng")
      .eq("usuario_id", r.prestador_id as string).eq("mis_servicios", true);
    return {
      destinos: (data ?? []) as Dispositivo[],
      critico: false,
      titulo: "Nuevo pedido a tu servicio",
      cuerpo: `${r.cliente_nombre ?? "Un vecino"}: ${r.detalle ?? ""}`,
    };
  }

  if (tipo === "foro") {
    const destinos = sinAutor(await dispositivos("foro"));
    return { destinos, critico: false, titulo: "Nuevo tema en el foro", cuerpo: String(r.titulo ?? "") };
  }
  return null;
}

async function dispositivos(columna: string): Promise<Dispositivo[]> {
  const { data, error } = await db.from("dispositivos").select("token, usuario_id, lat, lng").eq(columna, true);
  if (error) throw error;
  return (data ?? []) as Dispositivo[];
}

async function coordinadores(): Promise<Set<string>> {
  const ids = new Set<string>();
  const { data: b } = await db.from("brigadistas").select("vecino_id").eq("estado", "activo");
  b?.forEach((x) => ids.add(x.vecino_id as string));
  const { data: p } = await db.from("perfiles").select("id").in("rol", ["moderador", "organizacion"]);
  p?.forEach((x) => ids.add(x.id as string));
  return ids;
}

function distanciaKm(lat1: number, lng1: number, lat2: number, lng2: number) {
  const rad = (g: number) => (g * Math.PI) / 180;
  const a = Math.sin(rad(lat2 - lat1) / 2) ** 2 +
    Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(rad(lng2 - lng1) / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.sqrt(a));
}

// --------------------------------------------------------- envío con FCM

async function enviarATodos(tokens: string[], titulo: string, cuerpo: string, critico: boolean, tipo: string) {
  if (tokens.length === 0) return 0;
  const cuenta = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);
  const acceso = await tokenDeAcceso(cuenta);
  const url = `https://fcm.googleapis.com/v1/projects/${cuenta.project_id}/messages:send`;
  let enviados = 0;
  const invalidos: string[] = [];

  await Promise.all(tokens.map(async (token) => {
    const res = await fetch(url, {
      method: "POST",
      headers: { Authorization: `Bearer ${acceso}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: {
          token,
          notification: { title: titulo, body: cuerpo },
          data: { tipo },
          android: {
            priority: "HIGH",
            notification: {
              channel_id: critico ? "emergencias" : "avisos",
              sound: "default",
              color: critico ? "#E53935" : "#1E293B",
            },
          },
        },
      }),
    });
    if (res.ok) enviados++;
    else if (res.status === 404 || res.status === 400) invalidos.push(token); // app desinstalada
  }));

  if (invalidos.length) await db.from("dispositivos").delete().in("token", invalidos);
  return enviados;
}

// JWT firmado con la cuenta de servicio → token OAuth de Google.
async function tokenDeAcceso(cuenta: { client_email: string; private_key: string }) {
  const ahora = Math.floor(Date.now() / 1000);
  const b64 = (o: unknown) => btoa(JSON.stringify(o)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  const sinFirma = `${b64({ alg: "RS256", typ: "JWT" })}.${b64({
    iss: cuenta.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: ahora,
    exp: ahora + 3600,
  })}`;
  const pem = cuenta.private_key.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const clave = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const firma = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", clave, new TextEncoder().encode(sinFirma)));
  const jwt = `${sinFirma}.${btoa(String.fromCharCode(...firma)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_")}`;
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const json = await res.json();
  if (!json.access_token) throw new Error(`OAuth de Google falló: ${JSON.stringify(json)}`);
  return json.access_token as string;
}
