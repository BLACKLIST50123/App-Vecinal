import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../ui/widgets.dart';
import 'inicio.dart';
import 'listas.dart';
import 'mapa.dart';
import 'perfil.dart';
import 'publicar.dart';
import 'qr_screens.dart';

/// Estructura principal. Cuando el moderador activa la emergencia, la app
/// entera cambia: color rojo, nuevo inicio y pestañas de emergencia de
/// ambos módulos (grupos de apoyo y tablero humanitario).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  bool? _modoAnterior;

  void _irA(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final e = st.modoEmergencia;
    if (_modoAnterior != null && _modoAnterior != e) _tab = 0;
    _modoAnterior = e;

    final paginas = e
        ? [
            EmergenciaScreen(irA: _irA),
            const ServiciosScreen(emergencia: true),
            const FavoresScreen(emergencia: true),
            const MapaScreen(),
          ]
        : [
            InicioScreen(irA: _irA),
            const ServiciosScreen(emergencia: false),
            const FavoresScreen(emergencia: false),
            const MapaScreen(),
          ];
    final destinos = e
        ? const [
            NavigationDestination(icon: Icon(Icons.sos_outlined), selectedIcon: Icon(Icons.sos), label: 'Emergencia'),
            NavigationDestination(icon: Icon(Icons.health_and_safety_outlined), selectedIcon: Icon(Icons.health_and_safety), label: 'Apoyo'),
            NavigationDestination(icon: Icon(Icons.volunteer_activism_outlined), selectedIcon: Icon(Icons.volunteer_activism), label: 'Ayuda'),
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
          ]
        : const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
            NavigationDestination(icon: Icon(Icons.handyman_outlined), selectedIcon: Icon(Icons.handyman), label: 'Servicios'),
            NavigationDestination(icon: Icon(Icons.diversity_3_outlined), selectedIcon: Icon(Icons.diversity_3), label: 'Solidaridad'),
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
          ];
    final titulos = e
        ? const ['Emergencia', 'Grupos de apoyo', 'Tablero de ayuda', 'Mapa de ayuda']
        : const ['App Vecinal', 'Servicios y productos', 'Favores y solidaridad', 'Mapa del barrio'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: e ? const Color(0xFFB71C1C) : null,
        foregroundColor: e ? Colors.white : null,
        title: Text(titulos[_tab], style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Llevar mensajes por QR',
            icon: Badge(
              isLabelVisible: st.pendientes > 0,
              label: Text('${st.pendientes}'),
              child: const Icon(Icons.qr_code_scanner),
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendientesScreen())),
          ),
          IconButton(
            tooltip: st.logueado ? 'Mi perfil y ajustes' : 'Ingresar y ajustes de accesibilidad',
            icon: Icon(st.logueado ? Icons.account_circle : Icons.settings_accessibility),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PerfilScreen())),
          ),
        ],
      ),
      body: Column(children: [
        if (e && _tab != 0) const BannerEmergencia(),
        const BannerConexion(),
        Expanded(child: paginas[_tab]),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'publicar',
        backgroundColor: e ? const Color(0xFFB71C1C) : null,
        foregroundColor: e ? Colors.white : null,
        onPressed: () => abrirMenuPublicar(context),
        icon: const Icon(Icons.add_circle, size: 28),
        label: Text(e ? 'Pedir o dar ayuda' : 'Publicar'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _irA,
        destinations: destinos,
      ),
    );
  }
}
