import 'package:flutter/services.dart';

import 'sos_navegacion.dart';

/// Atajo con botones físicos: 3 pulsaciones seguidas de cualquier botón de
/// volumen (en menos de 2 s) abren el SOS sin mirar la pantalla.
///
/// Límite honesto: funciona con App Vecinal abierta. Activarlo con la
/// pantalla apagada requiere un servicio nativo de Android (roadmap).
class AtajoVolumenSos {
  static const _pulsaciones = 3;
  static const _ventana = Duration(seconds: 2);
  static final List<DateTime> _marcas = [];
  static bool _instalado = false;

  static void instalar() {
    if (_instalado) return;
    _instalado = true;
    HardwareKeyboard.instance.addHandler(_alPresionar);
  }

  static bool _alPresionar(KeyEvent evento) {
    final esVolumen = evento.logicalKey == LogicalKeyboardKey.audioVolumeUp ||
        evento.logicalKey == LogicalKeyboardKey.audioVolumeDown;
    if (!esVolumen || evento is! KeyDownEvent) return false;

    final ahora = DateTime.now();
    _marcas
      ..add(ahora)
      ..removeWhere((t) => ahora.difference(t) > _ventana);
    if (_marcas.length >= _pulsaciones) {
      _marcas.clear();
      HapticFeedback.heavyImpact();
      abrirSos();
    }
    // false: el sistema sigue cambiando el volumen con normalidad.
    return false;
  }
}
