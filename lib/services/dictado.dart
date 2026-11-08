import 'package:speech_to_text/speech_to_text.dart';

/// Dictado por voz con el reconocimiento del propio celular (costo cero).
/// El vecino dice "necesito una escalera" y se llena el título.
class Dictado {
  static final SpeechToText _stt = SpeechToText();
  static bool? _disponible;
  static String? _idioma;
  static void Function(bool escuchando)? _alCambiar;

  static bool get escuchando => _stt.isListening;

  /// true si el celular puede reconocer voz. Pide permiso del micrófono la
  /// primera vez. Si no hay permiso o servicio, la app sigue funcionando.
  static Future<bool> preparar() async {
    if (_disponible != null) return _disponible!;
    try {
      _disponible = await _stt.initialize(
        onStatus: (s) => _alCambiar?.call(s == SpeechToText.listeningStatus),
        onError: (_) => _alCambiar?.call(false),
      );
      if (_disponible!) _idioma = await _elegirIdioma();
    } catch (_) {
      _disponible = false;
    }
    return _disponible!;
  }

  /// Español del Perú si existe; si no, cualquier español; si no, el del sistema.
  static Future<String?> _elegirIdioma() async {
    try {
      final ids = (await _stt.locales()).map((l) => l.localeId).toList();
      for (final pref in ['es_PE', 'es-PE', 'es_419', 'es-419', 'es_US', 'es-US', 'es_ES', 'es-ES']) {
        if (ids.contains(pref)) return pref;
      }
      for (final id in ids) {
        if (id.toLowerCase().startsWith('es')) return id;
      }
    } catch (_) {}
    return null;
  }

  /// Escucha hasta que la persona deja de hablar (3 s de silencio) o 30 s.
  static Future<bool> escuchar({
    required void Function(String texto, bool esFinal) alTexto,
    required void Function(bool escuchando) alCambiar,
  }) async {
    if (!await preparar()) return false;
    _alCambiar = alCambiar;
    try {
      await _stt.listen(
        onResult: (r) => alTexto(r.recognizedWords, r.finalResult),
        listenOptions: SpeechListenOptions(
          localeId: _idioma,
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
      );
      alCambiar(true);
      return true;
    } catch (_) {
      alCambiar(false);
      return false;
    }
  }

  static Future<void> detener() async {
    try {
      await _stt.stop();
    } catch (_) {}
    _alCambiar?.call(false);
  }

  /// Se llama al cerrar el formulario para no seguir escuchando.
  static Future<void> soltar() async {
    _alCambiar = null;
    try {
      if (_stt.isListening) await _stt.cancel();
    } catch (_) {}
  }
}
