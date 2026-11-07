import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Lectura en voz alta (accesibilidad para adultos mayores y personas con
/// baja visión o que no leen con facilidad).
class Voz {
  static final FlutterTts _tts = FlutterTts();
  static bool _listo = false;

  static Future<void> hablar(String texto) async {
    try {
      if (!_listo) {
        await _tts.setLanguage('es-ES');
        await _tts.setSpeechRate(kIsWeb ? 0.9 : 0.45);
        _listo = true;
      }
      await _tts.stop();
      await _tts.speak(texto);
    } catch (_) {
      // Si el dispositivo no tiene voz instalada, la app sigue funcionando.
    }
  }

  static Future<void> callar() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
