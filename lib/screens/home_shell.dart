import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../features/solidaridad/solidaridad_screen.dart';
import '../services/voz.dart';
import '../state/app_state.dart';
import '../ui/diseno.dart';
import '../ui/tema.dart';
import '../ui/widgets.dart';
import 'aportes.dart';
import 'inicio.dart';
import 'listas.dart';
import 'mapa.dart';
import 'perfil.dart';
import 'publicar.dart';
import 'qr_screens.dart';
import '../features/sos/sos_navegacion.dart';

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
      // Día a día: Solidaridad (colectas + apoyar/pedir). Emergencia: tablero.
      e ? const FavoresScreen(emergencia: true) : SolidaridadScreen(irAPerfil: () => _irA(4)),
      MisAportesScreen(alIrAServicios: () => _irA(1)),
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
      ('Mis aportes', 'Administra tus servicios y pedidos'),
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
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2),
        label: 'Mis aportes',
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
          : 'Inicio. Busca lo que necesitas, mira lo más recomendado cerca de ti y cuántos vecinos necesitan una mano. Para una emergencia, toca el botón rojo SOS arriba.',
      e ? 'Grupos de apoyo para la emergencia. Toca uno para llamar.' : 'Servicios y productos de tu barrio. Usa el buscador o los filtros. Cada tarjeta muestra sus Vistos Buenos y el precio.',
      e
          ? 'Tablero de ayuda. Aquí ves quién necesita ayuda y qué cosas hay para compartir.'
          : 'Solidaridad. Aquí los vecinos se ayudan sin dinero. Toca Publicar para pedir apoyo, dar apoyo u organizar un evento solidario.',
      'Mis aportes. Administra los pedidos que te llegan y edita tus servicios y productos.',
      'Tu perfil: tu reconocimiento en el barrio, tu historial y los ajustes de accesibilidad.',
    ];
    // Cada pestaña publica lo suyo: Servicios → servicio; Solidaridad → apoyo/evento.
    // Solidaridad (día a día) ya tiene su propio formulario para pedir ayuda.
    final mostrarFab = e ? _tab <= 2 : _tab == 1;
    void alPublicar() {
      if (e) {
        abrirMenuPublicar(context);
      } else if (_tab == 1) {
        abrirFormulario(context, TipoForm.servicio);
      } else {
        abrirMenuSolidaridad(context);
      }
    }

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
                const _BotonSOSCabecera(),
                _MenuCabecera(
                  pendientes: st.pendientes,
                  voz: st.voz,
                  alEscuchar: () => Voz.hablar(resumenes[_tab]),
                  alCambiarLetra: () {
                    final tamano = st.cambiarLetra();
                    avisar('Letra $tamano');
                    if (st.voz) Voz.hablar('Letra $tamano');
                  },
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
                  onPressed: alPublicar,
                  icon: const Icon(Icons.add, size: 26),
                  label: Text(e ? 'Pedir o dar ayuda' : 'Publicar'),
                ),
              ),
            ),
      // Con letra grande, las etiquetas de la barra crecen poco para no partirse
      // ("Solidari-dad"); el resto de la pantalla sí usa el tamaño elegido.
      bottomNavigationBar: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.1),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => _irA(i),
          destinations: destinos,
        ),
      ),
    );
  }
}

/// Menú hamburguesa de la cabecera: Mapa, QR y Audio en un solo botón.
class _MenuCabecera extends StatelessWidget {
  const _MenuCabecera({
    required this.pendientes,
    required this.voz,
    required this.alEscuchar,
    required this.alCambiarLetra,
  });
  final int pendientes;
  final bool voz;
  final VoidCallback alEscuchar;
  final VoidCallback alCambiarLetra;

  @override
  Widget build(BuildContext context) {
    void ir(Widget p) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => p));
    return MenuAnchor(
      alignmentOffset: const Offset(-140, 6),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.map_outlined),
          onPressed: () => ir(const PantallaMapaCompleto()),
          child: const Text('Mapa del barrio'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.qr_code_scanner),
          onPressed: () => ir(const PendientesScreen()),
          child: Text(
            pendientes > 0 ? 'QR · $pendientes por enviar' : 'Mensajes por QR',
          ),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.format_size),
          onPressed: alCambiarLetra,
          child: const Text('Tamaño de letra'),
        ),
        if (voz)
          MenuItemButton(
            leadingIcon: const Icon(Icons.volume_up_outlined),
            onPressed: alEscuchar,
            child: const Text('Escuchar esta página'),
          ),
      ],
      builder: (context, menu, _) => BotonCuadrado(
        icono: menu.isOpen ? Icons.close : Icons.menu,
        tooltip: 'Más opciones',
        contador: pendientes,
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}

/// Botón SOS de cabecera:
/// Fondo rojo vibrante con bordes redondeados, icono de alerta blanco y texto SOS blanco.
class _BotonSOSCabecera extends StatelessWidget {
  const _BotonSOSCabecera();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'SOS · Auxilio rápido',
      child: Semantics(
        button: true,
        label: 'SOS. Abrir auxilio rápido.',
        excludeSemantics: true,
        child: Material(
          color: Paleta.rojo,
          elevation: 2,
          shadowColor: Paleta.rojo.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: abrirSos,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.crisis_alert_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
