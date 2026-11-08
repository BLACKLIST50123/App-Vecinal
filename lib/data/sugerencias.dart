import 'package:flutter/material.dart';

/// Frase rápida para publicar sin escribir: un toque llena el título y
/// elige la categoría. Pensado para adultos mayores y para quien no escribe
/// con facilidad.
class FraseRapida {
  const FraseRapida(this.texto, this.categoria, this.icono, {this.critica = false});
  final String texto;
  final String categoria;
  final IconData icono;

  /// Marca el pedido como "Riesgo de vida" (solo pedidos de emergencia).
  final bool critica;
}

/// Frases por tipo de formulario (clave = nombre del `TipoForm`).
const frasesRapidas = <String, List<FraseRapida>>{
  'pidoFavor': [
    FraseRapida('Necesito una escalera', 'herramientas', Icons.stairs),
    FraseRapida('Necesito un taladro', 'herramientas', Icons.hardware),
    FraseRapida('Necesito ayuda para cargar algo', 'ayuda', Icons.front_hand),
    FraseRapida('Necesito que alguien me lleve', 'movilidad', Icons.directions_car),
    FraseRapida('Busco compañía para un adulto mayor', 'cuidado', Icons.elderly),
    FraseRapida('Quiero aprender a usar el celular', 'habilidad', Icons.phone_android),
  ],
  'ofrezcoFavor': [
    FraseRapida('Regalo ropa en buen estado', 'donacion', Icons.checkroom),
    FraseRapida('Presto mis herramientas', 'herramientas', Icons.build),
    FraseRapida('Puedo ayudar a cargar cosas', 'ayuda', Icons.front_hand),
    FraseRapida('Enseño a usar el celular', 'habilidad', Icons.phone_android),
    FraseRapida('Puedo llevar a alguien en mi carro', 'movilidad', Icons.directions_car),
    FraseRapida('Acompaño a un adulto mayor', 'cuidado', Icons.elderly),
  ],
  'colecta': [
    FraseRapida('Útiles escolares para niños del sector', 'colecta', Icons.backpack),
    FraseRapida('Víveres para la olla común', 'colecta', Icons.soup_kitchen),
    FraseRapida('Medicinas para un vecino enfermo', 'colecta', Icons.medication),
  ],
  'servicio': [
    FraseRapida('Gasfitero a domicilio', 'gasfiteria', Icons.plumbing),
    FraseRapida('Electricista a domicilio', 'electricidad', Icons.electrical_services),
    FraseRapida('Clases de refuerzo escolar', 'clases', Icons.school),
    FraseRapida('Pan recién horneado', 'panaderia', Icons.bakery_dining),
    FraseRapida('Menú casero del día', 'comida', Icons.restaurant),
    FraseRapida('Paseo perros', 'mascotas', Icons.pets),
  ],
  'grupoApoyo': [
    FraseRapida('Brigada de primeros auxilios', 'salud', Icons.local_hospital),
    FraseRapida('Albergue temporal', 'albergue', Icons.night_shelter),
    FraseRapida('Olla común', 'alimentos', Icons.soup_kitchen),
    FraseRapida('Apoyo emocional', 'psicologico', Icons.psychology),
  ],
  'necesitoAyuda': [
    FraseRapida('Necesitamos agua potable', 'agua_alimento', Icons.water_drop),
    FraseRapida('Necesitamos comida', 'agua_alimento', Icons.restaurant),
    FraseRapida('Necesito medicinas', 'salud', Icons.medication),
    FraseRapida('Necesitamos un lugar para dormir', 'albergue', Icons.night_shelter),
    FraseRapida('Mi casa se inundó', 'rescate', Icons.flood),
    FraseRapida('Estamos atrapados, necesitamos salir', 'rescate', Icons.emergency, critica: true),
  ],
  'reportarVulnerable': [
    FraseRapida('Adulto mayor solo y sin agua', 'vulnerable', Icons.elderly),
    FraseRapida('Persona enferma sin medicinas', 'vulnerable', Icons.medication),
    FraseRapida('Persona con discapacidad necesita ayuda', 'vulnerable', Icons.accessible),
  ],
  'ofrezcoRecurso': [
    FraseRapida('Tengo agua para compartir', 'agua_alimento', Icons.water_drop),
    FraseRapida('Tengo comida para compartir', 'agua_alimento', Icons.restaurant),
    FraseRapida('Tengo medicinas básicas', 'salud', Icons.medication),
    FraseRapida('Ofrezco un lugar para dormir', 'albergue', Icons.night_shelter),
    FraseRapida('Tengo frazadas y ropa', 'recurso', Icons.inventory_2),
  ],
};

/// Palabras clave → categoría. Sirve para el texto dictado o escrito:
/// "necesito un gasfitero" elige Gasfitería sin que el vecino lo busque.
/// Sin IA de pago: solo coincidencias simples, sin tildes.
const _palabrasClave = <String, List<String>>{
  // Cadena de favores
  'herramientas': ['escalera', 'taladro', 'herramienta', 'martillo', 'alicate', 'carretilla', 'prest'],
  'movilidad': ['llev', 'carro', 'auto', 'taxi', 'moto', 'movilidad', 'viaje'],
  'cuidado': ['compania', 'acompan', 'adulto mayor', 'abuel', 'cuid', 'nino'],
  'habilidad': ['ensen', 'aprend', 'tarea'],
  'donacion': ['regal', 'donac', 'dono', 'ropa', 'juguete'],
  'ayuda': ['cargar', 'mano', 'mudanza', 'ayud'],
  // Servicios y productos
  'gasfiteria': ['gasfit', 'cano', 'desague', 'fuga', 'tuberia', 'inodoro'],
  'electricidad': ['electric', 'luz', 'enchufe', 'foco', 'cable'],
  'carpinteria': ['carpint', 'mueble', 'madera', 'puerta'],
  'cerrajeria': ['cerraj', 'llave', 'chapa', 'candado'],
  'albanileria': ['albanil', 'pared', 'construc', 'cemento', 'techo'],
  'mascotas': ['perro', 'gato', 'mascota', 'pase'],
  'clases': ['clase', 'refuerzo', 'profesor', 'matematica', 'ingles'],
  'costura': ['costur', 'basta', 'coser', 'zurc'],
  'tecnologia': ['celular', 'computadora', 'laptop', 'internet', 'televisor'],
  'panaderia': ['pan', 'torta', 'postre', 'queque'],
  'comida': ['menu', 'comida', 'almuerzo', 'cena', 'ceviche'],
  'bodega': ['bodega', 'abarrote', 'gaseosa'],
  // Emergencia
  'rescate': ['atrapad', 'inund', 'derrumb', 'salir', 'rescat', 'incendio'],
  'agua_alimento': ['agua', 'comida', 'viveres', 'alimento', 'leche'],
  'albergue': ['dormir', 'albergue', 'refugio', 'techo'],
  'salud': ['medicin', 'herid', 'enferm', 'pastilla', 'doctor', 'primeros auxilios'],
  'recurso': ['frazada', 'linterna', 'pila', 'ropa', 'colchon'],
  'psicologico': ['emocional', 'psicolog', 'ansiedad'],
  'alimentos': ['olla comun', 'comedor', 'viveres'],
};

String _normalizar(String s) {
  const de = 'áéíóúüñ';
  const a = 'aeiouun';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = de.indexOf(c);
    b.write(i >= 0 ? a[i] : c);
  }
  return b.toString();
}

/// Sugiere una categoría de `permitidas` según el texto, o null si no hay
/// una coincidencia clara. Gana la categoría con más palabras clave; en
/// empate, la que aparece primero en `permitidas`.
String? sugerirCategoria(String texto, List<String> permitidas) {
  final t = _normalizar(texto);
  if (t.trim().length < 3) return null;
  final palabras = t.split(RegExp(r'[^a-z0-9]+')).where((p) => p.isNotEmpty).toList();
  // Una clave de una palabra coincide con el inicio de una palabra
  // ("gasfit" → "gasfitero"); una de varias palabras, con el texto.
  bool coincide(String clave) =>
      clave.contains(' ') ? t.contains(clave) : palabras.any((p) => p.startsWith(clave));
  String? mejor;
  var puntos = 0;
  for (final id in permitidas) {
    final claves = _palabrasClave[id];
    if (claves == null) continue;
    final n = claves.where(coincide).length;
    if (n > puntos) {
      mejor = id;
      puntos = n;
    }
  }
  return mejor;
}
