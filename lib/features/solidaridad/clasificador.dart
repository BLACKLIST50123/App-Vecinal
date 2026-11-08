/// Clasifica una petición escrita libremente ("Necesito que me presten una
/// escalera hoy") en una de las 5 categorías del reto, por palabras clave, y
/// detecta si es urgente. Si no reconoce nada, queda en "otros".
class Clasificador {
  /// Raíces de palabras (sin tildes, en minúsculas). Se buscan al inicio de
  /// cada palabra, así "prest" reconoce prestar, préstamo y presten.
  static const palabras = <String, List<String>>{
    'herramientas': [
      'prest', 'escalera', 'taladro', 'martillo', 'carretilla', 'pala', 'manguera', 'herramienta',
      'extension', 'alicate', 'desarmador', 'serrucho', 'sierra', 'llave inglesa', 'gata', 'escoba',
    ],
    'movilidad': [
      'llev', 'traslad', 'movilidad', 'carro', 'auto', 'taxi', 'hospital', 'cita', 'recog', 'viaje',
      'transporte', 'moto', 'aeropuerto', 'terminal',
    ],
    'donacion': [
      'donar', 'donacion', 'regal', 'ropa', 'utiles', 'cemento', 'ladrillo', 'madera', 'pintura',
      'colchon', 'frazada', 'viveres', 'alimento', 'comida', 'juguete', 'zapat', 'cuaderno', 'mueble',
    ],
    'habilidad': [
      'ensen', 'clase', 'aprend', 'tarea', 'ingles', 'matematica', 'reparar', 'celular', 'computadora',
      'laptop', 'intercambi', 'tutor', 'curriculum', 'tramite',
    ],
    'ayuda': [
      'cargar', 'mudanza', 'mudar', 'cuidar', 'cuidado', 'acompan', 'compras', 'limpiar', 'pasear',
      'regar', 'cocinar', 'una mano', 'apoyo', 'vigilar',
    ],
  };

  static const _urgentes = [
    'urgente', 'urgencia', 'ya', 'ahora', 'hoy', 'rapido', 'cuanto antes', 'inmediat', 'emergencia', 'pronto',
  ];

  static String normalizar(String s) {
    const con = 'áéíóúüñÁÉÍÓÚÜÑ';
    const sin = 'aeiouunAEIOUUN';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = con.indexOf(ch);
      b.write(i >= 0 ? sin[i] : ch);
    }
    return b.toString().toLowerCase();
  }

  static bool _aparece(String texto, String raiz) => RegExp('(^|[^a-z])${RegExp.escape(raiz)}').hasMatch(texto);

  /// Categoría con más coincidencias, o 'otros' si no reconoce ninguna.
  static ({String categoria, bool detectada}) categoria(String texto) {
    final t = normalizar(texto);
    var mejor = 'otros';
    var puntos = 0;
    for (final e in palabras.entries) {
      final n = e.value.where((p) => _aparece(t, p)).length;
      if (n > puntos) {
        puntos = n;
        mejor = e.key;
      }
    }
    return (categoria: mejor, detectada: puntos > 0);
  }

  static bool esUrgente(String texto) {
    final t = normalizar(texto);
    return _urgentes.any((p) => RegExp('(^|[^a-z])${RegExp.escape(p)}([^a-z]|\$)').hasMatch(t) || (p.endsWith('t') && _aparece(t, p)));
  }
}
