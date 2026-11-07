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

class ObservadorSos extends NavigatorObserver {
  void _cambiar(Route<dynamic>? r, int delta) {
    if (r is PopupRoute) {
      final v = ventanasAbiertas.value + delta;
      // Se difiere para no notificar durante la construcción.
      WidgetsBinding.instance.addPostFrameCallback((_) => ventanasAbiertas.value = v < 0 ? 0 : v);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _cambiar(route, 1);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _cambiar(route, -1);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _cambiar(route, -1);
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
