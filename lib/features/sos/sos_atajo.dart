import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sos_navegacion.dart';

/// Atajo con botones físicos: 3 pulsaciones seguidas de cualquier botón de
/// volumen (en menos de 2 s) abren el SOS sin mirar la pantalla.
///
/// En Android los botones de volumen no llegan a Flutter (los toma el
/// control de volumen del sistema), así que MainActivity.kt los escucha y
/// avisa por el canal "conecta_vecino/botones". En otras plataformas se usa
/// el teclado físico de Flutter.
///
/// Límite honesto: funciona con la app abierta en pantalla. Con la pantalla
/// apagada o la app cerrada haría falta un servicio de accesibilidad.
class AtajoVolumenSos {
  static const _pulsaciones = 3;
  static const _ventana = Duration(seconds: 2);
  static const _canal = MethodChannel('conecta_vecino/botones');
  static final List<DateTime> _marcas = [];
  static bool _instalado = false;

  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void instalar() {
    if (_instalado) return;
    _instalado = true;
    if (_android) {
      _canal.setMethodCallHandler((llamada) async {
        if (llamada.method == 'volumen') registrarPulsacion();
      });
    } else {
      HardwareKeyboard.instance.addHandler(_alPresionar);
    }
  }

  static bool _alPresionar(KeyEvent evento) {
    final esVolumen = evento.logicalKey == LogicalKeyboardKey.audioVolumeUp ||
        evento.logicalKey == LogicalKeyboardKey.audioVolumeDown;
    if (esVolumen && evento is KeyDownEvent) registrarPulsacion();
    // false: el sistema sigue cambiando el volumen con normalidad.
    return false;
  }

  /// Cuenta una pulsación; a la tercera dentro de la ventana abre el SOS.
  @visibleForTesting
  static bool registrarPulsacion({DateTime? ahora}) {
    final t = ahora ?? DateTime.now();
    _marcas
      ..add(t)
      ..removeWhere((m) => t.difference(m) > _ventana);
    if (_marcas.length < _pulsaciones) return false;
    _marcas.clear();
    HapticFeedback.heavyImpact();
    abrirSos();
    return true;
  }
}
