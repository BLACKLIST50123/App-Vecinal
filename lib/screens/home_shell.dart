import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../features/emergencia/emergencia_screen.dart';
import '../features/emergencia/panel_coordinacion.dart';
import '../features/inicio/mapa_inicio.dart';
import '../features/recomendar/contactos_pendientes.dart';
import '../features/solidaridad/solidaridad_screen.dart';
import '../services/voz.dart';
import '../state/app_state.dart';
import '../ui/diseno.dart';
import '../ui/tema.dart';
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

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Al abrir la app: ¿hay algún servicio que contactó y puede recomendar?
    WidgetsBinding.instance.addPostFrameCallback((_) => _preguntarRecomendacion());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver a la app (por ejemplo, después de llamar al gasfitero).
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) _preguntarRecomendacion();
  }

  void _preguntarRecomendacion() {
    if (!mounted) return;
    final st = context.read<AppState>();
    if (st.modoEmergencia) return; // en emergencia no se interrumpe
    ContactosPendientes.revisar(context, st.prefs, logueado: st.logueado);
  }
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
        ? <Widget>[
            EmergenciaScreen(irA: (i) => _irA(i)),
            const _MapaEmergencia(),
            // Solo la junta (moderador): gestionar los pedidos y SOS.
            if (st.esModerador) const PanelSos(),
            const PerfilScreen(),
          ]
        : <Widget>[
            InicioScreen(irA: _irA),
            ServiciosScreen(
              key: ValueKey('serv-$_grupo-$_consulta'),
              emergencia: false,
              grupoInicial: _grupo,
              consultaInicial: _consulta,
            ),
            SolidaridadScreen(
              key: ValueKey('sol-$_grupo-$_consulta'),
              irAPerfil: () => _irA(4),
              iniciarEnPedir: _grupo == 'pedir',
              textoInicial: _grupo == 'pedir' ? _consulta : null,
            ),
            // Mis aportes vive en Perfil.
            ForoScreen(key: ValueKey('foro-$_consulta'), consultaInicial: _tab == 3 ? _consulta : null),
            const PerfilScreen(),
          ];
    if (_tab >= paginas.length) _tab = 0;

    final encabezados = e
        ? <(String, String?)>[
            ('Emergencia', st.emergencia.titulo),
            ('Mapa de ayuda', 'Solo esta emergencia'),
            if (st.esModerador) ('Pedidos y SOS', 'Deriva y asigna cada aviso'),
            ('Mi perfil', st.logueado ? null : 'Estás como visitante'),
          ]
        : <(String, String?)>[
            ('Hola, ${st.logueado ? st.nombre.split(' ').first : 'vecino'}',
                [if (st.sector != null) st.sector!, 'Conecta Vecino'].join(' · ')),
            ('Servicios y productos', 'Compra local en ${Zona.nombre}'),
            ('Solidaridad', 'Juntos hacemos más'),
            ('Foro Vecinal', 'Preguntas, servicios y diálogo de barrio'),
            ('Mi perfil', st.logueado ? null : 'Estás como visitante'),
          ];

    // Perfil con puntito rojo: recuerda activar los avisos de emergencia.
    final perfil = NavigationDestination(
      icon: Badge(
        isLabelVisible: st.faltaActivarAvisos,
        smallSize: 10,
        backgroundColor: Paleta.rojo,
        child: const Icon(Icons.person_outline),
      ),
      selectedIcon: Badge(
        isLabelVisible: st.faltaActivarAvisos,
        smallSize: 10,
        backgroundColor: Paleta.rojo,
        child: const Icon(Icons.person),
      ),
      label: 'Perfil',
      tooltip: st.faltaActivarAvisos ? 'Perfil: falta activar los avisos de emergencia' : null,
    );
    final destinos = e
        ? <NavigationDestination>[
            const NavigationDestination(icon: Icon(Icons.sos_outlined), selectedIcon: Icon(Icons.sos), label: 'Emergencia'),
            NavigationDestination(
              icon: const Icon(Icons.map_outlined),
              selectedIcon: const Icon(Icons.map),
              // Con 4 pestañas (moderador) el texto corto no se parte.
              label: st.esModerador ? 'Mapa' : 'Mapa de ayuda',
              tooltip: 'Mapa de ayuda',
            ),
            if (st.esModerador)
              const NavigationDestination(
                icon: Icon(Icons.dashboard_customize_outlined),
                selectedIcon: Icon(Icons.dashboard_customize),
                label: 'SOS',
                tooltip: 'Pedidos de ayuda y SOS',
              ),
            perfil,
          ]
        : <NavigationDestination>[
            const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
            const NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Servicios'),
            const NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Solidaridad'),
            const NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: 'Foro'),
            perfil,
          ];

    final (titulo, subtitulo) = encabezados[_tab];

    // Un solo "Escuchar" por página: resume qué hay y qué se puede hacer.
    const resumenPerfil = 'Tu perfil: tu reconocimiento en el barrio, tu historial y los ajustes de accesibilidad.';
    final resumenes = e
        ? <String>[
            'Emergencia. ${st.emergencia.titulo ?? ''}. ${st.emergencia.mensaje ?? ''}. Avisa si estás bien o toca Necesito ayuda. '
                'Si hay riesgo de vida, llama al 105, 106 o 116.',
            'Mapa de ayuda. Solo lo de esta emergencia: vecinos que necesitan ayuda y puntos de ayuda como albergues o postas. '
                'Toca un punto para ayudar, llamar o ver cómo llegar.',
            if (st.esModerador)
              'Pedidos y SOS. Cada aviso de esta emergencia con fecha y hora. Tócalo para derivarlo a las autoridades, asignarlo a un brigadista o cambiar su estado.',
            resumenPerfil,
          ]
        : <String>[
            'Inicio. Arriba, escribe o di lo que necesitas y te llevamos al lugar correcto. Luego ves lo más recomendado '
                'cerca de ti, las buenas noticias del barrio y el mapa. Para una emergencia, toca el botón rojo SOS arriba.',
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

