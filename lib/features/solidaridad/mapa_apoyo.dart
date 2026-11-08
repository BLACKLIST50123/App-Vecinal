import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models.dart';
import '../../state/app_state.dart';
import '../../ui/widgets.dart';
import '../../util.dart';
import 'tarjeta_apoyo.dart';
import '../../ui/tema.dart';

/// Mapa SOLO de peticiones para apoyar (de la categoría elegida), con la
/// más cercana resaltada.
class MapaApoyoScreen extends StatelessWidget {
  const MapaApoyoScreen({super.key, required this.peticiones, this.categoria});
  final List<Publicacion> peticiones; // ya filtradas y ordenadas por cercanía
  final String? categoria;

  static Color get _naranja => Paleta.ambar;
  static Color get _rojo => Paleta.rojo;

  void _ver(BuildContext context, Publicacion p) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
            child: TarjetaApoyo(p, ancho: double.infinity),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final ref = st.referencia;
    final conLugar = peticiones.where((p) => p.punto != null).toList();
    final masCercana = conLugar.isEmpty ? null : conLugar.first;
    final titulo = categoria == null ? 'Peticiones cerca de ti' : buscarCategoria(categoria!).nombre;

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: Stack(children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: masCercana == null ? LatLng(ref.lat, ref.lng) : LatLng(masCercana.punto!.lat, masCercana.punto!.lng),
            initialZoom: 14.5,
            minZoom: 11,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.alphacoders.appvecinal',
              tileBuilder: Paleta.oscuro ? darkModeTileBuilder : null, // mapa oscuro en modo oscuro
            ),
            MarkerLayer(markers: [
              // Tu ubicación
              Marker(
                point: LatLng(ref.lat, ref.lng),
                width: 26,
                height: 26,
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
              for (final p in conLugar.reversed) // la más cercana se dibuja encima
                Marker(
                  point: LatLng(p.punto!.lat, p.punto!.lng),
                  width: p == masCercana ? 60 : 44,
                  height: p == masCercana ? 60 : 44,
                  child: Semantics(
                    button: true,
                    label: '${p == masCercana ? 'Más cercana. ' : ''}${p.titulo}',
                    child: GestureDetector(
                      onTap: () => _ver(context, p),
                      child: Container(
                        decoration: BoxDecoration(
                          color: p.esUrgente ? _rojo : _naranja,
                          shape: BoxShape.circle,
                          border: Border.all(color: p == masCercana ? Paleta.oro : Colors.white, width: p == masCercana ? 5 : 3),
                          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
                        ),
                        child: Icon(
                          p == masCercana ? Icons.star : buscarCategoria(p.categoria).icono,
                          color: Colors.white,
                          size: p == masCercana ? 30 : 22,
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ],
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: ColoredBox(
            color: Paleta.superficie.withValues(alpha: 0.85),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text('© OpenStreetMap', style: TextStyle(fontSize: 11, color: Paleta.tinta)),
            ),
          ),
        ),
        // Leyenda + acceso directo a la más cercana
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: Card(
            margin: EdgeInsets.zero,
            child: masCercana == null
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('No hay peticiones con ubicación en esta categoría.'),
                  )
                : ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Paleta.oroFondo,
                      child: Icon(Icons.star, color: Paleta.oro),
                    ),
                    title: Text('Más cercana · ${formatoDistancia(distanciaKm(ref, masCercana.punto!))}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(masCercana.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _ver(context, masCercana),
                  ),
          ),
        ),
        if (!st.online)
          const Positioned(
            left: 12,
            right: 12,
            bottom: 36,
            child: EstadoVacio(icono: Icons.cloud_off, texto: 'Sin internet el mapa puede no cargar.'),
          ),
      ]),
    );
  }
}
