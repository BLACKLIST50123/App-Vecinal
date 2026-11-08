import '../../config.dart';
import '../../data/sugerencias.dart';
import '../solidaridad/clasificador.dart';

/// A dónde lleva "¿Qué necesitas hoy?".
enum DestinoNecesidad { emergencia, foro, solidaridad, servicio, buscar }

class Necesidad {
  const Necesidad(this.destino, this.texto, {this.categoria});
  final DestinoNecesidad destino;
  final String texto;

  /// Categoría detectada (de servicios o de solidaridad), si la hay.
  final String? categoria;
}

String _norm(String s) {
  const de = 'áéíóúüñ¿?¡!';
  const a = 'aeiouun    ';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = de.indexOf(c);
    b.write(i >= 0 ? a[i] : c);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

const _emergencia = [
  'incendio', 'fuego', 'herid', 'atrapad', 'no respira', 'desmay', 'sangr', 'inund', 'huaico', 'derrumb',
  'accidente', 'choque', 'robo', 'asalt', 'emergencia', 'auxilio', 'socorro', 'fuga de gas', 'temblor', 'sismo',
];

const _pregunta = [
  'alguien conoce', 'alguien sabe', 'alguien tiene', 'recomiend', 'donde hay', 'donde puedo', 'donde consigo',
  'que opinan', 'conocen a', 'conocen un', 'saben de', 'quien sabe', 'quien conoce',
];

// Pedir algo prestado, regalado o una mano: eso lo resuelven los vecinos.
const _favor = [
  'prest', 'regal', 'done', 'donen', 'donac', 'me lleve', 'me lleven', 'acompan', 'cargar', 'mudanza',
  'ayuda para', 'una mano', 'me ayuden', 'ayudame', 'ayudenme',
];

/// Entiende lo que la persona escribió o dijo y elige a dónde llevarla.
/// Orden: emergencia → pregunta para el foro → favor entre vecinos →
/// servicio o producto → favor detectado → buscar en servicios.
/// Sin IA de pago: palabras clave (funciona sin internet).
Necesidad interpretarNecesidad(String texto) {
  final t = _norm(texto);
  bool tiene(List<String> claves) => claves.any(t.contains);
  if (t.length < 2) return Necesidad(DestinoNecesidad.buscar, texto);

  if (tiene(_emergencia)) return Necesidad(DestinoNecesidad.emergencia, texto);
  if (tiene(_pregunta)) return Necesidad(DestinoNecesidad.foro, texto);

  final favor = Clasificador.categoria(texto);
  if (tiene(_favor)) {
    return Necesidad(DestinoNecesidad.solidaridad, texto, categoria: favor.detectada ? favor.categoria : 'otros');
  }
  final servicio = sugerirCategoria(texto, [for (final c in categoriasServicio) c.id]);
  if (servicio != null) return Necesidad(DestinoNecesidad.servicio, texto, categoria: servicio);
  if (favor.detectada) return Necesidad(DestinoNecesidad.solidaridad, texto, categoria: favor.categoria);
  return Necesidad(DestinoNecesidad.buscar, texto);
}
