import 'dart:math';

import 'config.dart';

double _rad(double g) => g * pi / 180;

/// Distancia en km entre dos puntos (fórmula de Haversine).
double distanciaKm(Punto a, Punto b) {
  const r = 6371.0;
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(a.lat)) * cos(_rad(b.lat)) * sin(dLng / 2) * sin(dLng / 2);
  return 2 * r * asin(min(1.0, sqrt(h)));
}

/// Distancia redondeada a 500 m, para ordenar "cerca" sin que unos metros
/// de diferencia ganen a un servicio mucho mejor recomendado.
double distanciaKmRedondeada(Punto a, Punto b) => (distanciaKm(a, b) * 2).roundToDouble() / 2;

bool enZona(Punto p) => distanciaKm(p, Zona.centro) <= Zona.radioKm;

/// Sector de la zona más cercano a un punto (para sugerirlo al registrarse).
String sectorMasCercano(Punto p) => Zona.sectores.entries
    .reduce((a, b) => distanciaKm(p, a.value) <= distanciaKm(p, b.value) ? a : b)
    .key;

/// Privacidad: los pedidos de ayuda se publican con ubicación aproximada
/// (cuadrícula de ~220 m + desplazamiento aleatorio de hasta ~110 m), para
/// no revelar dónde vive una persona vulnerable o quién está sola.
Punto aproximar(Punto p) {
  final r = Random();
  double f(double v) => (v * 450).roundToDouble() / 450 + (r.nextDouble() - 0.5) * 0.002;
  return Punto(f(p.lat), f(p.lng));
}

String formatoDistancia(double km) =>
    km < 1 ? 'a ${(km * 1000 / 10).round() * 10} m' : 'a ${km.toStringAsFixed(1)} km';

/// Fecha y hora claras: "Hoy 14:30", "Ayer 09:15", "Mié 5 nov · 18:40".
String fechaHora(DateTime t) {
  const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  final hora = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final hoy = DateTime.now();
  final dia = DateTime(t.year, t.month, t.day);
  final diferencia = DateTime(hoy.year, hoy.month, hoy.day).difference(dia).inDays;
  if (diferencia == 0) return 'Hoy $hora';
  if (diferencia == 1) return 'Ayer $hora';
  return '${dias[t.weekday - 1]} ${t.day} ${meses[t.month - 1]} · $hora';
}

String haceCuanto(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'hace un momento';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  if (d.inDays == 1) return 'ayer';
  return 'hace ${d.inDays} días';
}

/// UUID v4 generado en el teléfono: permite crear publicaciones sin
/// internet y evita duplicados si dos vecinos suben el mismo QR.
String nuevoId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

String soloDigitos(String s) => s.replaceAll(RegExp(r'\D'), '');
