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

bool enZona(Punto p) => distanciaKm(p, Zona.centro) <= Zona.radioKm;

String formatoDistancia(double km) =>
    km < 1 ? 'a ${(km * 1000 / 10).round() * 10} m' : 'a ${km.toStringAsFixed(1)} km';

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
