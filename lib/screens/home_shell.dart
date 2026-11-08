import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/voz.dart';
import '../state/app_state.dart';
import '../ui/diseno.dart';
import '../ui/widgets.dart';
import 'foro.dart';
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
  bool _fabVisible = true;
  String? _grupo; // filtro inicial para Servicios (desde Inicio)
  String? _consulta; // búsqueda inicial para Servicios (desde Inicio)

  void _irA(int i, {String? grupo, String? consulta}) => setState(() {
    _tab = i;
    _grupo = grupo;
    _consulta = consulta;
    _fabVisible = true;
  });

  /// El botón Publicar se esconde al bajar (no tapa contenido) y vuelve al subir.
  bool _alDesplazar(UserScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final visible = switch (n.direction) {
      ScrollDirection.reverse => false,
      ScrollDirection.forward => true,
      _ => _fabVisible,
    };
    if (visible != _fabVisible) setState(() => _fabVisible = visible);
    return false;
  }

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
      const ForoScreen(),
      const PerfilScreen(),
    ];

    final encabezados = <(String, String?)>[
      e
          ? ('Emergencia', st.emergencia.titulo)
          : (
              'Hola, ${st.logueado ? st.nombre.split(' ').first : 'vecino'}',
              fechaLarga(DateTime.now()),
            ),
      e
          ? ('Grupos de apoyo', 'Emergencia')
          : ('Servicios y productos', 'Compra local en ${Zona.nombre}'),
      e
          ? ('Tablero de ayuda', 'Emergencia')
          : ('Solidaridad', 'Juntos hacemos más'),
      ('Foro Vecinal', 'Preguntas, servicios y diálogo de barrio'),
      ('Mi perfil', st.logueado ? null : 'Estás como visitante'),
    ];

    final destinos = <NavigationDestination>[
      e
          ? const NavigationDestination(
              icon: Icon(Icons.sos_outlined),
              selectedIcon: Icon(Icons.sos),
              label: 'Emergencia',
            )
          : const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
      e
          ? const NavigationDestination(
              icon: Icon(Icons.health_and_safety_outlined),
              selectedIcon: Icon(Icons.health_and_safety),
              label: 'Apoyo',
            )
          : const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'Servicios',
            ),
      e
          ? const NavigationDestination(
              icon: Icon(Icons.volunteer_activism_outlined),
              selectedIcon: Icon(Icons.volunteer_activism),
              label: 'Ayuda',
            )
          : const NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: 'Solidaridad',
            ),
      const NavigationDestination(
        icon: Icon(Icons.forum_outlined),
        selectedIcon: Icon(Icons.forum),
        label: 'Foro',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Perfil',
      ),
    ];

    final (titulo, subtitulo) = encabezados[_tab];

    // Un solo "Escuchar" por página: resume qué hay y qué se puede hacer.
    final resumenes = <String>[
      e
          ? 'Emergencia. ${st.emergencia.titulo ?? ''}. ${st.emergencia.mensaje ?? ''}. Para pedir ayuda, toca el botón rojo Necesito ayuda.'
          : 'Inicio. Busca servicios y productos, explora tu barrio o entra a Solidaridad para pedir o dar una mano.',
      e ? 'Grupos de apoyo para la emergencia. Toca uno para llamar.' : 'Servicios y productos de tu barrio. Usa el buscador o los filtros. Cada tarjeta muestra sus Vistos Buenos y el precio.',
      e
          ? 'Tablero de ayuda. Aquí ves quién necesita ayuda y qué cosas hay para compartir.'
          : 'Solidaridad. Aquí los vecinos se ayudan sin dinero. Puedes pedir una mano, dar algo o aportar a una colecta.',
      'Foro vecinal. Conversa con tus vecinos, pide recomendaciones o pregunta por servicios que necesitas en tu barrio.',
      'Tu perfil: tu reconocimiento en el barrio, tu historial y los ajustes de accesibilidad.',
    ];
    final mostrarFab = _tab != 3 && _tab != 4 && (e || _tab != 2);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (e && _tab != 0) const BannerEmergencia(),
            const BannerConexion(),
            EncabezadoPantalla(
              titulo: titulo,
              subtitulo: subtitulo,
              acciones: [
                BotonCuadrado(
                  icono: Icons.map_outlined,
                  tooltip: 'Mapa del barrio',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PantallaMapaCompleto(),
                    ),
                  ),
                ),
                if (st.voz)
                  BotonCuadrado(
                    icono: Icons.volume_up_outlined,
                    tooltip: 'Escuchar esta página',
                    onTap: () => Voz.hablar(resumenes[_tab]),
                  ),
                BotonCuadrado(
                  icono: Icons.qr_code_scanner,
                  tooltip: 'Llevar mensajes por QR',
                  contador: st.pendientes,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PendientesScreen()),
                  ),
                ),
              ],
            ),
            Expanded(
              child: NotificationListener<UserScrollNotification>(
                onNotification: _alDesplazar,
                child: paginas[_tab],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: !mostrarFab
          ? null
          : AnimatedSlide(
              offset: _fabVisible ? Offset.zero : const Offset(0, 2),
              duration: const Duration(milliseconds: 200),
              child: AnimatedOpacity(
                opacity: _fabVisible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: FloatingActionButton.extended(
                  heroTag: 'publicar',
                  onPressed: () => abrirMenuPublicar(context),
                  icon: const Icon(Icons.add, size: 26),
                  label: Text(e ? 'Pedir o dar ayuda' : 'Publicar'),
                ),
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => _irA(i),
        destinations: destinos,
      ),
    );
  }
}
