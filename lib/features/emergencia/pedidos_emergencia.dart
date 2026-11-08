import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models.dart';
import '../../screens/detalles.dart';
import '../../state/app_state.dart';
import '../../ui/tema.dart';
import '../../ui/widgets.dart';
import '../../util.dart';

/// Pedidos de ayuda de ESTA emergencia (incluye los SOS), sin repetir y sin
/// resueltos. Sirve para la lista, el mapa y el contador.
Future<List<Publicacion>> cargarPedidosEmergencia(AppState st) async {
  final r = await Future.wait([st.repo.publicaciones(emergencia: true), st.repo.alertasSos()]);
  return filtrarPedidosEmergencia([...r[1], ...r[0]], desde: st.emergencia.desde);
}

/// Función pura (para pruebas): solo pedidos abiertos creados desde [desde].
List<Publicacion> filtrarPedidosEmergencia(List<Publicacion> todas, {DateTime? desde}) {
  final vistos = <String>{};
  return [
    for (final p in todas)
      if (p.esPedido &&
          p.estado != 'resuelta' &&
          (desde == null || !p.creado.isBefore(desde.toLocal())) &&
          vistos.add(p.id))
        p,
  ];
}

/// Todos los reportes de "Necesito ayuda" y SOS de esta emergencia: primero
/// los más graves, luego los más cercanos. Cada uno lleva al mapa.
class PedidosEmergenciaScreen extends StatelessWidget {
  const PedidosEmergenciaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos de ayuda')),
      body: Cargador<List<Publicacion>>(
        claves: [st.emergencia.clave],
        cargar: cargarPedidosEmergencia,
        builder: (context, pedidos) {
          final ref = st.referencia;
          double d(Publicacion p) => p.punto == null ? 9999 : distanciaKm(ref, p.punto!);
          final lista = [...pedidos]
            ..sort((a, b) {
              final x = b.pesoPrioridad.compareTo(a.pesoPrioridad);
              return x != 0 ? x : d(a).compareTo(d(b));
            });
          if (lista.isEmpty) {
            return const EstadoVacio(icono: Icons.check_circle_outline, texto: 'Nadie ha pedido ayuda en esta emergencia.');
          }
          return RefreshIndicator(
            onRefresh: () async => st.refrescar(),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
              Text('${lista.length} ${lista.length == 1 ? 'pedido' : 'pedidos'} en esta emergencia · los más graves primero',
                  style: TextStyle(fontSize: 14, color: Paleta.gris)),
              const SizedBox(height: 10),
              for (final p in lista) _FilaPedido(p, km: p.punto == null ? null : d(p)),
            ]),
          );
        },
      ),
    );
  }
}

class _FilaPedido extends StatelessWidget {
  const _FilaPedido(this.p, {this.km});
  final Publicacion p;
  final double? km;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final propio = (st.uid != null && p.autorId == st.uid) || p.id == st.miPedidoEmergencia?['id'];
    final critica = p.prioridad == 'critica';
    final color = propio ? Paleta.azulInfo : (critica ? Paleta.rojo : Paleta.ambar);
    final cat = buscarCategoria(p.categoria, emergencia: true);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Paleta.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: critica ? Paleta.rojo.withValues(alpha: 0.5) : Paleta.linea, width: critica ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicacionDetalle(publicacion: p))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(cat.icono, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                    child: Text(propio ? 'TU PEDIDO' : (critica ? 'MUY URGENTE' : 'URGENTE'),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.3)),
                  ),
                  const SizedBox(height: 4),
                  Text(p.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Paleta.tinta)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (km != null) formatoDistancia(km!),
                      if (p.sector != null) p.sector!,
                      haceCuanto(p.creado),
                      if (p.origen == 'sos') 'SOS',
                    ].join(' · '),
                    style: TextStyle(fontSize: 13, color: Paleta.gris),
                  ),
                  if (p.ayudantes > 0)
                    Text('${p.ayudantes} ${p.ayudantes == 1 ? 'vecino va' : 'vecinos van'} a ayudar',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Paleta.verde)),
                ]),
              ),
            ]),
            if (p.punto != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MapaPedidoScreen(p))),
                  icon: const Icon(Icons.place_rounded, size: 18),
                  label: const Text('Ver en el mapa'),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Mapa centrado en un pedido de ayuda (ubicación aproximada) y en ti.
class MapaPedidoScreen extends StatelessWidget {
  const MapaPedidoScreen(this.p, {super.key});
  final Publicacion p;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final punto = p.punto!;
    final yo = st.ubicacion;
    return Scaffold(
      appBar: AppBar(title: Text(p.titulo, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Stack(children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(punto.lat, punto.lng),
            initialZoom: 16,
            minZoom: 11,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.alphacoders.appvecinal'),
            // Zona aproximada (±200 m): no se muestra la casa exacta.
            CircleLayer(circles: [
              CircleMarker(
                point: LatLng(punto.lat, punto.lng),
                radius: 200,
                useRadiusInMeter: true,
                color: Paleta.rojo.withValues(alpha: 0.12),
                borderColor: Paleta.rojo.withValues(alpha: 0.6),
                borderStrokeWidth: 2,
              ),
            ]),
            MarkerLayer(markers: [
              Marker(
                point: LatLng(punto.lat, punto.lng),
                width: 46,
                height: 46,
                child: Container(
                  decoration: BoxDecoration(
                    color: Paleta.rojo,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
                  ),
                  child: const Icon(Icons.front_hand_rounded, color: Colors.white, size: 22),
                ),
              ),
              if (yo != null)
                Marker(
                  point: LatLng(yo.lat, yo.lng),
                  width: 24,
                  height: 24,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2962FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                  ),
                ),
            ]),
          ],
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 16,
          child: Material(
            color: Paleta.superficie,
            elevation: 6,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(p.titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      [formatoDistancia(distanciaKm(st.referencia, punto)), if (p.sector != null) p.sector!, 'zona aproximada']
                          .join(' · '),
                      style: TextStyle(fontSize: 12, color: Paleta.gris),
                    ),
                  ]),
                ),
                FilledButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicacionDetalle(publicacion: p))),
                  child: const Text('Ayudar'),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
