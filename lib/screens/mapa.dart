import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/inicio/mapa_inicio.dart';
import '../state/app_state.dart';

/// Mapa del barrio a pantalla completa: los mismos filtros y pines que el
/// mapa del Inicio (Todos, Emergencias, Peticiones, Servicios, Productos).
class PantallaMapaCompleto extends StatelessWidget {
  const PantallaMapaCompleto({super.key});

  @override
  Widget build(BuildContext context) {
    final emergencia = context.watch<AppState>().modoEmergencia;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa del barrio'),
        actions: [
          IconButton(
            tooltip: 'Salir de pantalla completa',
            icon: const Icon(Icons.fullscreen_exit),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(child: MapaYCercanos(emergencia: emergencia, pantallaCompleta: true)),
    );
  }
}
