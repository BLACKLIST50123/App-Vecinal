import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';
import '../util.dart';

/// Geolocalización de servicios, recursos y necesidades de apoyo.
/// Incluye vista de lista ordenada por distancia (accesible para lectores
/// de pantalla y útil sin internet, cuando el mapa no carga).
class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  bool _servicios = true, _pedidos = true, _ofertas = true, _comoLista = false;

  static const _cServicio = Color(0xFF1565C0);
  static const _cPedido = Color(0xFFE65100);
  static const _cOferta = Color(0xFF2E7D32);
  static const _cCritico = Color(0xFFE53935);

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
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), children: [
          FilterChip(
            avatar: const CircleAvatar(backgroundColor: _cServicio, radius: 8),
            label: Text(emergencia ? 'Grupos de apoyo' : 'Servicios'),
            selected: _servicios,
            onSelected: (v) => setState(() => _servicios = v),
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: const CircleAvatar(backgroundColor: _cPedido, radius: 8),
            label: const Text('Necesitan ayuda'),
            selected: _pedidos,
            onSelected: (v) => setState(() => _pedidos = v),
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: const CircleAvatar(backgroundColor: _cOferta, radius: 8),
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
        ]),
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
                        color: const Color(0xFF2962FF),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                    ),
                  ),
                ),
            ];

            return Stack(children: [
              FlutterMap(
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
                  ),
                  MarkerLayer(markers: marcadores),
                ],
              ),
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: Colors.white70,
                  child: const Text('© OpenStreetMap', style: TextStyle(fontSize: 11, color: Colors.black)),
                ),
              ),
              if (!st.online)
                const Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Card(
                    color: Color(0xFFFFE082),
                    child: ListTile(
                      leading: Icon(Icons.cloud_off, color: Colors.black87),
                      title: Text('Sin internet el mapa puede no cargar. Usa "Ver como lista".',
                          style: TextStyle(color: Colors.black87)),
                    ),
                  ),
                ),
              Positioned(
                right: 12,
                bottom: 96,
                child: FloatingActionButton.small(
                  heroTag: 'ubicarme',
                  tooltip: 'Usar mi ubicación',
                  onPressed: () => st.ubicar(),
                  child: const Icon(Icons.my_location),
                ),
              ),
            ]);
          },
        ),
      ),
    ]);
  }
}
