import 'package:flutter/material.dart';

import '../../models.dart';
import 'sos_screen.dart';

/// Navegador global: permite abrir el SOS desde cualquier pantalla
/// (botón flotante o atajo de volumen), aunque estén fuera del árbol de rutas.
final navegador = GlobalKey<NavigatorState>();

/// true mientras la pantalla SOS está abierta (oculta el botón flotante).
final sosAbierto = ValueNotifier<bool>(false);

/// Último SOS recibido en tiempo real cerca del vecino (≤ 2 km): se muestra
/// como aviso rojo arriba de la pantalla, en cualquier pantalla.
final alertaEntrante = ValueNotifier<(Publicacion, double)?>(null);

/// Radio en el que un SOS le llega a un vecino.
const radioAlertaKm = 2.0;

/// Cantidad de menús o diálogos abiertos: el botón SOS se oculta para no
/// tapar sus opciones.
final ventanasAbiertas = ValueNotifier<int>(0);

/// Cuenta los menús y diálogos abiertos para ocultar el botón SOS mientras
/// están en pantalla. El contador se actualiza al instante (no a partir de
/// un valor viejo), así nunca queda "trabado" y el botón siempre vuelve.
class ObservadorSos extends NavigatorObserver {
  final Set<Route<dynamic>> _abiertas = {};
  bool _programado = false;

  void _publicar() {
    if (_programado) return;
    _programado = true;
    // Se difiere para no notificar durante la construcción de la pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _programado = false;
      ventanasAbiertas.value = _abiertas.length;
    });
  }

  void _abrir(Route<dynamic>? r) {
    if (r is PopupRoute && _abiertas.add(r)) _publicar();
  }

  void _cerrar(Route<dynamic>? r) {
    if (r != null && _abiertas.remove(r)) _publicar();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _abrir(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _cerrar(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _cerrar(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _cerrar(oldRoute);
    _abrir(newRoute);
  }

  /// Solo para pruebas.
  int get abiertas => _abiertas.length;
}

final observadorSos = ObservadorSos();

void abrirSos() {
  if (sosAbierto.value) return;
  navegador.currentState?.push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => const SosScreen(),
      transitionsBuilder: (_, animacion, _, hijo) => FadeTransition(opacity: animacion, child: hijo),
    ),
  );
}
