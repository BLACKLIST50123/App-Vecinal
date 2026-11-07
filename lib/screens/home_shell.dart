import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../state/app_state.dart';
import '../ui/diseno.dart';
import '../ui/widgets.dart';
import 'inicio.dart';
import 'listas.dart';
import 'mapa.dart';
import 'perfil.dart';
import 'publicar.dart';
import 'qr_screens.dart';

/// Estructura principal (diseño Figma): encabezado propio en cada pestaña,
/// barra inferior blanca y botón de publicar. Con emergencia activa, toda
/// la app cambia a rojo y las pestañas pasan a modo emergencia.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  bool? _modoAnterior;
  String? _grupo; // filtro inicial para Servicios (desde Inicio)
  String? _consulta; // búsqueda inicial para Servicios (desde Inicio)

  void _irA(int i, {String? grupo, String? consulta}) => setState(() {
        _tab = i;
        _grupo = grupo;
        _consulta = consulta;
      });

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final e = st.modoEmergencia;
    if (_modoAnterior != null && _modoAnterior != e) _tab = 0;
    _modoAnterior = e;

    final paginas = <Widget>[
      e ? EmergenciaScreen(irA: (i) => _irA(i)) : InicioScreen(irA: _irA),
      ServiciosScreen(
        key: ValueKey('serv-$e-$_grupo-$_consulta'),
        emergencia: e,
        grupoInicial: _grupo,
        consultaInicial: _consulta,
      ),
      FavoresScreen(emergencia: e),
      const MapaScreen(),
      const PerfilScreen(),
    ];

    final encabezados = <(String, String?)>[
      e ? ('Emergencia', st.emergencia.titulo) : ('Hola, ${st.logueado ? st.nombre.split(' ').first : 'vecino'}', fechaLarga(DateTime.now())),
      e ? ('Grupos de apoyo', 'Emergencia') : ('Servicios y productos', 'Compra local en ${Zona.nombre}'),
      e ? ('Tablero de ayuda', 'Emergencia') : ('Solidaridad', 'Juntos hacemos más'),
      e ? ('Mapa de ayuda', 'Emergencia') : ('Mapa del barrio', 'Todo cerca de ti'),
      ('Mi perfil', st.logueado ? null : 'Estás como visitante'),
    ];

    final destinos = <NavigationDestination>[
      e
          ? const NavigationDestination(icon: Icon(Icons.sos_outlined), selectedIcon: Icon(Icons.sos), label: 'Emergencia')
          : const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
      e
          ? const NavigationDestination(icon: Icon(Icons.health_and_safety_outlined), selectedIcon: Icon(Icons.health_and_safety), label: 'Apoyo')
          : const NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Servicios'),
      e
          ? const NavigationDestination(icon: Icon(Icons.volunteer_activism_outlined), selectedIcon: Icon(Icons.volunteer_activism), label: 'Ayuda')
          : const NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Solidaridad'),
      const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
      const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
    ];

    final (titulo, subtitulo) = encabezados[_tab];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          if (e && _tab != 0) const BannerEmergencia(),
          const BannerConexion(),
          EncabezadoPantalla(
            titulo: titulo,
            subtitulo: subtitulo,
            acciones: [
              BotonCuadrado(
                icono: Icons.qr_code_scanner,
                tooltip: 'Llevar mensajes por QR',
                contador: st.pendientes,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendientesScreen())),
              ),
            ],
          ),
          Expanded(child: paginas[_tab]),
        ]),
      ),
      floatingActionButton: _tab == 4
          ? null
          : FloatingActionButton.extended(
              heroTag: 'publicar',
              onPressed: () => abrirMenuPublicar(context),
              icon: const Icon(Icons.add, size: 26),
              label: Text(e ? 'Pedir o dar ayuda' : (_tab == 2 ? 'Pedir ayuda' : 'Publicar')),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => _irA(i),
        destinations: destinos,
      ),
    );
  }
}
