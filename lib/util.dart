import 'dart:math';

import 'package:flutter/services.dart';

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

// ============================================================ validación

/// Filtros de teclado: solo se puede escribir lo que el campo acepta.
final soloNumeros = FilteringTextInputFormatter.digitsOnly;
final soloLetras = FilteringTextInputFormatter.allow(RegExp(r"[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ' -]"));
final formatoTelefono = <TextInputFormatter>[soloNumeros, LengthLimitingTextInputFormatter(9)];

/// Largos máximos (los mismos que exige la base de datos, migración 0014).
class Limites {
  static const nombre = 60;
  static const titulo = 120;
  static const texto = 500;
  static const comentario = 300;
  static const horario = 60;
  static const precio = 99999;
  static const personas = 50;
  static const meta = 1000;
}

String _sinTildes(String s) {
  const de = 'áéíóúüñÁÉÍÓÚÜÑ';
  const a = 'aeiouunAEIOUUN';
  final b = StringBuffer();
  for (final c in s.split('')) {
    final i = de.indexOf(c);
    b.write(i >= 0 ? a[i] : c);
  }
  return b.toString().toLowerCase();
}

/// Palabras ofensivas comunes (se comparan sin tildes y por palabra entera).
const _ofensivas = {
  'idiota', 'imbecil', 'estupido', 'estupida', 'tarado', 'tarada', 'cojudo', 'cojuda',
  'huevon', 'huevona', 'mierda', 'puta', 'puto', 'conchatumadre', 'ctm', 'csm', 'maricon',
  'cabron', 'pendejo', 'pendeja', 'carajo', 'webon', 'negro de mierda',
};

/// Revisa el contenido de un texto libre: lenguaje, datos privados y spam.
/// Devuelve el problema o null si está bien.
String? revisarContenido(String v) {
  final t = v.trim();
  if (t.isEmpty) return null;
  final n = _sinTildes(t);
  final palabras = n.split(RegExp(r'[^a-z0-9]+')).where((p) => p.isNotEmpty).toSet();
  if (_ofensivas.any((o) => o.contains(' ') ? n.contains(o) : palabras.contains(o))) {
    return 'Usa un lenguaje respetuoso con tus vecinos';
  }
  if (RegExp(r'(https?://|www\.|\b[a-z0-9-]+\.(com|net|org|pe|ly|io|app)\b)', caseSensitive: false).hasMatch(t)) {
    return 'Por seguridad no se permiten enlaces';
  }
  final digitos = t.replaceAll(RegExp(r'[\s-]'), '');
  if (RegExp(r'\d{13,19}').hasMatch(digitos)) {
    return 'No escribas números de tarjeta ni de cuenta';
  }
  if (RegExp(r'(^|\D)\d{8}(\D|$)').hasMatch(t) && RegExp(r'\bdni\b').hasMatch(n)) {
    return 'No escribas tu DNI: es un dato privado';
  }
  if (RegExp(r'(.)\1{6,}').hasMatch(t)) return 'Hay letras repetidas de más';
  final letras = t.replaceAll(RegExp(r'[^a-zA-ZáéíóúÁÉÍÓÚñÑ]'), '');
  if (letras.length >= 12 && letras == letras.toUpperCase()) {
    return 'Evita escribir todo en MAYÚSCULAS';
  }
  return null;
}

/// Celular peruano: 9 dígitos y empieza en 9. Vacío es válido si es opcional.
String? validarTelefono(String v, {bool obligatorio = false}) {
  final t = v.trim();
  if (t.isEmpty) return obligatorio ? 'Escribe tu celular' : null;
  if (!RegExp(r'^9\d{8}$').hasMatch(t)) return 'El celular debe tener 9 dígitos y empezar con 9';
  if (RegExp(r'^(\d)\1{8}$').hasMatch(t)) {
    return 'Ese número no parece real';
  }
  return null;
}

String? validarNombre(String v) {
  final t = v.trim();
  if (t.isEmpty) return 'Escribe tu nombre';
  if (!RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ' -]+$").hasMatch(t)) return 'Usa solo letras';
  if (t.replaceAll(RegExp(r"[' -]"), '').length < 2) return 'El nombre es muy corto';
  if (t.length > Limites.nombre) return 'El nombre es muy largo (máximo ${Limites.nombre} letras)';
  if (RegExp(r'(.)\1{3,}').hasMatch(t.toLowerCase())) return 'Revisa tu nombre: tiene letras repetidas';
  return revisarContenido(t) == 'Usa un lenguaje respetuoso con tus vecinos' ? 'Escribe tu nombre real' : null;
}

/// Título de una publicación, servicio o tema del foro.
String? validarTitulo(String v, {int min = 5, int max = Limites.titulo, String vacio = 'Escribe en pocas palabras de qué se trata'}) {
  final t = v.trim();
  if (t.isEmpty) return vacio;
  if (t.length < min) return 'Escribe un poco más (mínimo $min letras)';
  if (t.length > max) return 'Es muy largo (máximo $max letras)';
  if (t.replaceAll(RegExp(r'[^a-zA-ZáéíóúÁÉÍÓÚñÑ]'), '').length < 3) return 'Usa palabras, no solo números o signos';
  return revisarContenido(t);
}

/// Texto libre: largo mínimo y máximo, y contenido. Vacío es válido si es opcional.
String? validarTexto(String v, {int min = 15, int max = Limites.texto, bool obligatorio = false}) {
  final t = v.trim();
  if (t.isEmpty) return obligatorio ? 'Este campo es obligatorio' : null;
  if (t.length < min) return 'Escribe un poco más (mínimo $min letras)';
  if (t.length > max) return 'Es muy largo (máximo $max letras)';
  return revisarContenido(t);
}

/// Precio en soles, solo números. Vacío es válido (es opcional).
String? validarPrecio(String v) {
  final t = v.trim();
  if (t.isEmpty) return null;
  final n = int.tryParse(t);
  if (n == null) return 'Escribe solo números';
  if (n <= 0) return 'El precio debe ser mayor a 0';
  if (n > Limites.precio) return 'Revisa el precio: parece muy alto';
  return null;
}

/// Horario de atención (opcional): corto y sin datos raros.
String? validarHorario(String v) {
  final t = v.trim();
  if (t.isEmpty) return null;
  if (t.length < 4) return 'Ejemplo: Lun a Sáb, 8 am a 6 pm';
  if (t.length > Limites.horario) return 'Es muy largo (máximo ${Limites.horario} letras)';
  return revisarContenido(t);
}

/// Correo electrónico.
String? validarCorreo(String v) {
  final t = v.trim();
  if (t.isEmpty) return 'Escribe tu correo';
  if (!RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[a-zA-Z]{2,}$').hasMatch(t)) return 'Revisa tu correo (ejemplo: nombre@correo.com)';
  return null;
}

/// Clave: con celular son 6 números; con correo, al menos 8 caracteres
/// con letras y números. Se rechazan las claves fáciles de adivinar.
String? validarClave(String v, {required bool conCorreo, String? celular}) {
  if (v.isEmpty) return conCorreo ? 'Escribe tu contraseña' : 'Escribe tu clave de 6 números';
  if (!conCorreo) {
    if (!RegExp(r'^\d{6}$').hasMatch(v)) return 'La clave debe tener exactamente 6 números';
    if (RegExp(r'^(\d)\1{5}$').hasMatch(v) || '0123456789'.contains(v) || '9876543210'.contains(v)) {
      return 'Esa clave es muy fácil de adivinar';
    }
    if (celular != null && celular.length >= 6 && celular.endsWith(v)) {
      return 'No uses los últimos números de tu celular';
    }
    return null;
  }
  if (v.length < 8) return 'La contraseña debe tener al menos 8 caracteres';
  if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) return 'Usa letras y números';
  return null;
}

/// Número entero dentro de un rango (personas, meta de colecta, avance).
String? validarRango(int n, {required int min, required int max, String que = 'El número'}) {
  if (n < min) return '$que debe ser al menos $min';
  if (n > max) return '$que no puede ser mayor a $max';
  return null;
}

/// "30" → "S/ 30" para guardar; "Desde S/ 30" → "30" para editar.
String? precioGuardado(String v) => v.trim().isEmpty ? null : 'S/ ${v.trim()}';
String precioEditable(String? guardado) => soloDigitos(guardado ?? '');
