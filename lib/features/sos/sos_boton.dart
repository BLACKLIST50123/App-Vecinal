import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import 'sos_navegacion.dart';
import 'sos_tipos.dart';

/// Capa que muestra el botón SOS sobre TODAS las pantallas.
/// Se coloca en MaterialApp.builder, encima del navegador.
/// Se oculta durante el tutorial, con el teclado abierto o si el SOS ya está abierto.
class CapaSos extends StatelessWidget {
  const CapaSos({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final mq = MediaQuery.of(context);
    final teclado = mq.viewInsets.bottom > 0;
    return Stack(children: [
      child,
      ListenableBuilder(
        listenable: Listenable.merge([sosAbierto, ventanasAbiertas]),
        builder: (context, _) {
          final oculto =
              sosAbierto.value || ventanasAbiertas.value > 0 || teclado || !st.tutorialVisto || !st.rolElegido;
          if (oculto) return const SizedBox.shrink();
          return Positioned(
            left: 16,
            // Por encima de la barra de navegación inferior (74 px) en cualquier pantalla.
            bottom: mq.padding.bottom + 90,
            child: const BotonSos(),
          );
        },
      ),
    ]);
  }
}

/// Botón de pánico: redondo, rojo y con la palabra SOS (no solo un ícono).
class BotonSos extends StatelessWidget {
  const BotonSos({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'SOS. Abrir modo emergencia para pedir ayuda rápido.',
        excludeSemantics: true,
        child: Material(
          color: ColoresSos.rojo,
          shape: const CircleBorder(side: BorderSide(color: Colors.white, width: 3)),
          elevation: 6,
          shadowColor: ColoresSos.rojoOscuro,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.mediumImpact();
              abrirSos();
            },
            child: const SizedBox(
              width: 64,
              height: 64,
              child: Center(
                child: Text('SOS',
                    style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
          ),
        ),
      );
}
