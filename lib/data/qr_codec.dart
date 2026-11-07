import 'dart:convert';

/// "Mula de datos": convierte una publicación guardada sin internet en un
/// código QR. Otro vecino lo escanea y lo sube cuando tiene señal.
///
/// Solo viajan campos de contenido (lista blanca). Al leerlo, la
/// publicación queda marcada como origen 'qr' y sin autor, para que quien
/// la transporta no aparezca como autor ni pueda alterar su estado.
class QrCodec {
  static const _campos = {
    'id', 'tipo', 'categoria', 'titulo', 'descripcion', 'contacto_nombre',
    'contacto_telefono', 'personas', 'prioridad', 'es_emergencia', 'lat',
    'lng', 'sector', 'autor_nombre', 'creado_offline_en',
  };
  static final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

  static String codificar(Map<String, dynamic> datos) => jsonEncode({
        'app': 'vecinal',
        'v': 1,
        'd': {
          for (final e in datos.entries)
            if (_campos.contains(e.key) && e.value != null) e.key: e.value,
        },
      });

  /// Devuelve los datos listos para subir, o null si el QR no es válido.
  static Map<String, dynamic>? decodificar(String? texto) {
    if (texto == null || texto.length > 4000) return null;
    try {
      final j = jsonDecode(texto);
      if (j is! Map || j['app'] != 'vecinal' || j['d'] is! Map) return null;
      final d = <String, dynamic>{
        for (final e in (j['d'] as Map).entries)
          if (_campos.contains(e.key)) e.key.toString(): e.value,
      };
      if (d['id'] is! String || !_uuid.hasMatch(d['id'] as String)) return null;
      if (d['titulo'] is! String || (d['titulo'] as String).trim().length < 3) return null;
      if (d['tipo'] != 'pido' && d['tipo'] != 'ofrezco') return null;
      if (d['categoria'] is! String) return null;
      d['origen'] = 'qr';
      d['autor_id'] = null;
      return d;
    } catch (_) {
      return null;
    }
  }
}
