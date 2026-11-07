import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models.dart';
import '../../screens/detalles.dart';
import '../../state/app_state.dart';
import '../../util.dart';
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
      // Aviso de SOS cercano recibido en tiempo real.
      ValueListenableBuilder<(Publicacion, double)?>(
        valueListenable: alertaEntrante,
        builder: (context, alerta, _) {
          if (alerta == null || sosAbierto.value) return const SizedBox.shrink();
          return Positioned(
            top: mq.padding.top + 8,
            left: 12,
            right: 12,
            child: _AvisoSosCercano(publicacion: alerta.$1, km: alerta.$2),
          );
        },
      ),
    ]);
  }
}

/// Aviso rojo arriba: "🚨 Alerta SOS a 350 m". Se cierra solo en 45 s.
class _AvisoSosCercano extends StatefulWidget {
  const _AvisoSosCercano({required this.publicacion, required this.km});
  final Publicacion publicacion;
  final double km;

  @override
  State<_AvisoSosCercano> createState() => _AvisoSosCercanoState();
}

class _AvisoSosCercanoState extends State<_AvisoSosCercano> {
  Timer? _cierre;

  @override
  void initState() {
    super.initState();
    _cierre = Timer(const Duration(seconds: 45), _cerrar);
  }

  @override
  void didUpdateWidget(covariant _AvisoSosCercano old) {
    super.didUpdateWidget(old);
    if (old.publicacion.id != widget.publicacion.id) {
      _cierre?.cancel();
      _cierre = Timer(const Duration(seconds: 45), _cerrar);
    }
  }

  @override
  void dispose() {
    _cierre?.cancel();
    super.dispose();
  }

  void _cerrar() => alertaEntrante.value = null;

  @override
  Widget build(BuildContext context) {
    final p = widget.publicacion;
    final cat = buscarCategoria(p.categoria, emergencia: true);
    return Semantics(
      liveRegion: true,
      label: 'Alerta SOS ${formatoDistancia(widget.km)}: ${p.titulo}',
      child: Material(
        color: ColoresSos.rojo,
        elevation: 8,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(cat.icono, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('🚨 Alerta SOS ${formatoDistancia(widget.km)}',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  Text(p.titulo, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14)),
                ]),
              ),
              IconButton(
                tooltip: 'Cerrar aviso',
                onPressed: _cerrar,
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ]),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.white.withValues(alpha: 0.18)),
                onPressed: () {
                  _cerrar();
                  navegador.currentState?.push(MaterialPageRoute(builder: (_) => PublicacionDetalle(publicacion: p)));
                },
                child: const Text('Ver y ayudar'),
              ),
            ),
          ]),
        ),
      ),
    );
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
