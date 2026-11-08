import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';
import '../util.dart';
import '../ui/tema.dart';

/// Geolocalización de servicios, recursos y necesidades de apoyo.
/// Permite explorar el mapa, agrandar/achicar con zoom (+/-),
/// alternar a pantalla completa y ver como lista ordenada por distancia.
class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key, this.esPantallaCompleta = false});
  final bool esPantallaCompleta;

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final MapController _mapController = MapController();
  bool _servicios = true, _pedidos = true, _ofertas = true, _comoLista = false;

  static Color get _cServicio => Paleta.azulInfo;
  static Color get _cPedido => Paleta.ambar;
  static Color get _cOferta => Paleta.verde;
  static Color get _cCritico => Paleta.rojo;

  void _verDetalle(Widget tarjeta) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.only(bottom: 16), child: tarjeta)),
      );

  Marker _pin(Punto p, Color color, IconData icono, String etiqueta, VoidCallback onTap) => Marker(
        point: LatLng(p.lat, p.lng),
        width: 48,
        height: 48,
        child: Semantics(
          button: true,
          label: etiqueta,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
              ),
              child: Icon(icono, color: Colors.white, size: 24),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final emergencia = st.modoEmergencia;
    return Column(children: [
      SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            FilterChip(
              avatar: CircleAvatar(backgroundColor: _cServicio, radius: 8),
              label: Text(emergencia ? 'Grupos de apoyo' : 'Servicios'),
              selected: _servicios,
              onSelected: (v) => setState(() => _servicios = v),
            ),
            const SizedBox(width: 8),
            FilterChip(
              avatar: CircleAvatar(backgroundColor: _cPedido, radius: 8),
              label: const Text('Necesitan ayuda'),
              selected: _pedidos,
              onSelected: (v) => setState(() => _pedidos = v),
            ),
            const SizedBox(width: 8),
            FilterChip(
              avatar: CircleAvatar(backgroundColor: _cOferta, radius: 8),
              label: Text(emergencia ? 'Para compartir' : 'Ofrecen'),
              selected: _ofertas,
              onSelected: (v) => setState(() => _ofertas = v),
            ),
            const SizedBox(width: 8),
            ActionChip(
              avatar: Icon(_comoLista ? Icons.map : Icons.list),
              label: Text(_comoLista ? 'Ver mapa' : 'Ver como lista'),
              onPressed: () => setState(() => _comoLista = !_comoLista),
            ),
            if (!widget.esPantallaCompleta) ...[
              const SizedBox(width: 8),
              ActionChip(
                avatar: Icon(Icons.fullscreen, color: Paleta.azulInfo),
                label: const Text('Pantalla completa'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PantallaMapaCompleto()),
                ),
              ),
            ],
          ],
        ),
      ),
      Expanded(
        child: Cargador<(List<Servicio>, List<Publicacion>)>(
          claves: [emergencia],
          cargar: (st) async => (
            await st.repo.servicios(emergencia: emergencia),
            await st.repo.publicaciones(emergencia: emergencia),
          ),
          builder: (context, datos) {
            final servicios = _servicios ? datos.$1.where((s) => s.punto != null).toList() : <Servicio>[];
            final pubs = datos.$2
                .where((p) => p.punto != null && ((p.esPedido && _pedidos) || (!p.esPedido && _ofertas)))
                .toList();
            final ref = st.referencia;

            if (_comoLista) {
              final items = <(double, Widget)>[
                for (final s in servicios) (distanciaKm(ref, s.punto!), TarjetaServicio(s)),
                for (final p in pubs) (distanciaKm(ref, p.punto!), TarjetaPublicacion(p)),
              ]..sort((a, b) => a.$1.compareTo(b.$1));
              if (items.isEmpty) {
                return const EstadoVacio(icono: Icons.location_off, texto: 'Nada que mostrar con estos filtros.');
              }
              return ListView(padding: const EdgeInsets.only(bottom: 96), children: [for (final i in items) i.$2]);
            }

            final marcadores = <Marker>[
              for (final s in servicios)
                _pin(s.punto!, _cServicio, buscarCategoria(s.categoria, emergencia: s.esEmergencia).icono,
                    'Servicio: ${s.titulo}', () => _verDetalle(TarjetaServicio(s))),
              for (final p in pubs)
                _pin(
                  p.punto!,
                  p.esPedido ? (p.prioridad == 'critica' ? _cCritico : _cPedido) : _cOferta,
                  buscarCategoria(p.categoria, emergencia: p.esEmergencia).icono,
                  '${p.esPedido ? 'Necesita' : 'Ofrece'}: ${p.titulo}',
                  () => _verDetalle(TarjetaPublicacion(p)),
                ),
              if (st.ubicacion != null)
                Marker(
                  point: LatLng(st.ubicacion!.lat, st.ubicacion!.lng),
                  width: 28,
                  height: 28,
                  child: Semantics(
                    label: 'Tu ubicación',
                    child: Container(
                      decoration: BoxDecoration(
                        color: Paleta.azulInfo,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                    ),
                  ),
                ),
            ];

            return Stack(children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(ref.lat, ref.lng),
                  initialZoom: st.ubicacion != null ? 14.5 : 12.6,
                  minZoom: 11,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.alphacoders.appvecinal',
                    tileBuilder: Paleta.oscuro ? darkModeTileBuilder : null, // mapa oscuro en modo oscuro
                  ),
                  MarkerLayer(markers: marcadores),
                ],
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: Paleta.superficie.withValues(alpha: 0.85),
                  child: Text('© OpenStreetMap', style: TextStyle(fontSize: 11, color: Paleta.tinta)),
                ),
              ),
              if (!st.online)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Card(
                    color: Paleta.oroClaro,
                    child: ListTile(
                      leading: Icon(Icons.cloud_off, color: Paleta.tinta),
                      title: Text('Sin internet el mapa puede no cargar. Usa "Ver como lista".',
                          style: TextStyle(color: Paleta.tinta)),
                    ),
                  ),
                ),

              // Controles flotantes de exploración: Zoom (+ / -), Pantalla Completa y Ubicación GPS
              Positioned(
                right: 12,
                bottom: widget.esPantallaCompleta ? 24 : 96,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'map_zoomin_${widget.esPantallaCompleta}',
                      tooltip: 'Agrandar mapa (Acercar)',
                      onPressed: () {
                        final z = _mapController.camera.zoom;
                        _mapController.move(_mapController.camera.center, (z + 1).clamp(11.0, 18.0));
                      },
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'map_zoomout_${widget.esPantallaCompleta}',
                      tooltip: 'Achicar mapa (Alejar)',
                      onPressed: () {
                        final z = _mapController.camera.zoom;
                        _mapController.move(_mapController.camera.center, (z - 1).clamp(11.0, 18.0));
                      },
                      child: const Icon(Icons.remove),
                    ),
                    if (!widget.esPantallaCompleta) ...[
                      const SizedBox(height: 6),
                      FloatingActionButton.small(
                        heroTag: 'map_fullscreen_btn',
                        tooltip: 'Mostrar pantalla completa',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PantallaMapaCompleto()),
                        ),
                        child: const Icon(Icons.fullscreen),
                      ),
                    ],
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'map_ubicarme_${widget.esPantallaCompleta}',
                      tooltip: 'Centrar en mi ubicación',
                      onPressed: () async {
                        await st.ubicar();
                        if (st.ubicacion != null) {
                          _mapController.move(LatLng(st.ubicacion!.lat, st.ubicacion!.lng), 15);
                        }
                      },
                      child: const Icon(Icons.my_location),
                    ),
                  ],
                ),
              ),
            ]);
          },
        ),
      ),
    ]);
  }
}

/// Vista dedicada para explorar el mapa del barrio a pantalla completa
class PantallaMapaCompleto extends StatelessWidget {
  const PantallaMapaCompleto({super.key});

  @override
  Widget build(BuildContext context) {
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
      body: const SafeArea(child: MapaScreen(esPantallaCompleta: true)),
    );
  }
}
