import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../features/emergencia/emergencia_screen.dart';
import '../features/inicio/mapa_inicio.dart';
import '../features/solidaridad/solidaridad_screen.dart';
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
import '../features/sos/sos_cabecera.dart';

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

    // En emergencia la app se reduce a 3 pestañas, solo para esta emergencia:
    //   Emergencia (actuar ya) · Mapa de ayuda (quién necesita ayuda y puntos
    //   de ayuda, un solo mapa) · Perfil (siempre).
    final paginas = e
        ? <Widget>[EmergenciaScreen(irA: (i) => _irA(i)), const _MapaEmergencia(), const PerfilScreen()]
        : <Widget>[
            InicioScreen(irA: _irA),
            ServiciosScreen(
              key: ValueKey('serv-$_grupo-$_consulta'),
              emergencia: false,
              grupoInicial: _grupo,
              consultaInicial: _consulta,
            ),
            SolidaridadScreen(
              key: ValueKey('sol-$_grupo'),
              irAPerfil: () => _irA(4),
              iniciarEnPedir: _grupo == 'pedir',
            ),
            // Mis aportes vive en Perfil.
            const ForoScreen(),
            const PerfilScreen(),
          ];
    if (_tab >= paginas.length) _tab = 0;

    final encabezados = e
        ? <(String, String?)>[
            ('Emergencia', st.emergencia.titulo),
            ('Mapa de ayuda', 'Solo esta emergencia'),
            ('Mi perfil', st.logueado ? null : 'Estás como visitante'),
          ]
        : <(String, String?)>[
            ('Hola, ${st.logueado ? st.nombre.split(' ').first : 'vecino'}', fechaLarga(DateTime.now())),
            ('Servicios y productos', 'Compra local en ${Zona.nombre}'),
            ('Solidaridad', 'Juntos hacemos más'),
            ('Foro Vecinal', 'Preguntas, servicios y diálogo de barrio'),
            ('Mi perfil', st.logueado ? null : 'Estás como visitante'),
          ];

    const perfil = NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil');
    final destinos = e
        ? const <NavigationDestination>[
            NavigationDestination(icon: Icon(Icons.sos_outlined), selectedIcon: Icon(Icons.sos), label: 'Emergencia'),
            NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa de ayuda'),
            perfil,
          ]
        : const <NavigationDestination>[
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
            NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Servicios'),
            NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Solidaridad'),
            NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: 'Foro'),
            perfil,
          ];

    final (titulo, subtitulo) = encabezados[_tab];

    // Un solo "Escuchar" por página: resume qué hay y qué se puede hacer.
    const resumenPerfil = 'Tu perfil: tu reconocimiento en el barrio, tu historial y los ajustes de accesibilidad.';
    final resumenes = e
        ? <String>[
            'Emergencia. ${st.emergencia.titulo ?? ''}. ${st.emergencia.mensaje ?? ''}. Avisa si estás bien o toca Necesito ayuda. '
                'Abajo está tu punto de ayuda más cercano. Si hay riesgo de vida, llama al 105, 106 o 116.',
            'Mapa de ayuda. Solo lo de esta emergencia: vecinos que necesitan ayuda y puntos de ayuda como albergues o postas. '
                'Toca un punto para ayudar, llamar o ver cómo llegar.',
            resumenPerfil,
          ]
        : <String>[
            'Inicio. Arriba ves lo último que pasó en tu barrio. Luego el mapa con servicios, productos, peticiones y emergencias: '
                'usa los filtros o toca un punto. Para una emergencia, toca el botón rojo SOS arriba.',
            'Servicios y productos de tu barrio. Usa el buscador o los filtros. Cada tarjeta muestra sus Vistos Buenos y el precio.',
            'Solidaridad. Aquí los vecinos se ayudan sin dinero. Puedes pedir una mano, dar algo o aportar a una colecta.',
            'Foro vecinal. Conversa con tus vecinos, pide recomendaciones o pregunta por servicios que necesitas en tu barrio.',
            resumenPerfil,
          ];
    // Cada pestaña publica lo suyo: Servicios → servicio; Solidaridad → apoyo/evento.
    // Solidaridad (día a día) ya tiene su propio formulario para pedir ayuda.
    // En emergencia no hay botón flotante: las acciones ya están a la vista.
    final mostrarFab = !e && _tab == 1;
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
                const BotonSosCabecera(),
                _MenuCabecera(
                  pendientes: st.pendientes,
                  voz: st.voz,
                  emergencia: e,
                  alEscuchar: () => Voz.hablar(resumenes[_tab]),
                  alCambiarLetra: () {
                    final tamano = st.cambiarLetra();
                    avisar('Letra $tamano');
                    if (st.voz) Voz.hablar('Letra $tamano');
                  },
                ),
              ],
            ),
            // Emergencia nueva cerca: aviso corto bajo la cabecera.
            const AvisoEmergenciaNueva(),
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

/// Pestaña Mapa en emergencia: emergencias, pedidos y grupos de apoyo.
class _MapaEmergencia extends StatelessWidget {
  const _MapaEmergencia();

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: ListView(padding: const EdgeInsets.only(bottom: 40), children: const [MapaYCercanos(emergencia: true)]),
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
    this.emergencia = false,
  });
  final int pendientes;
  final bool voz;
  final bool emergencia;
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
        // En emergencia el foro sale de la barra, pero sigue a un toque.
        if (emergencia)
          MenuItemButton(
            leadingIcon: const Icon(Icons.forum_outlined),
            onPressed: () => ir(Scaffold(appBar: AppBar(title: const Text('Foro vecinal')), body: const ForoScreen())),
            child: const Text('Foro vecinal'),
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

