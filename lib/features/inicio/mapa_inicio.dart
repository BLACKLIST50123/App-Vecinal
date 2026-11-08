import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models.dart';
import '../../screens/detalles.dart';
import '../../screens/mapa.dart';
import '../../state/app_state.dart';
import '../../ui/diseno.dart';
import '../../ui/tema.dart';
import '../../ui/widgets.dart';
import '../../util.dart';

/// Tipos de punto del mapa del Inicio.
enum TipoPunto {
  servicio('Servicios', 'Servicio', Color(0xFFD9692F), Icons.handyman_rounded),
  producto('Productos', 'Producto', Color(0xFF2563EB), Icons.shopping_basket_rounded),
  peticion('Peticiones', 'Petición de ayuda', Color(0xFF7C3AED), Icons.front_hand_rounded),
  emergencia('Emergencias', 'Emergencia', Color(0xFFE53935), Icons.sos_rounded);

  const TipoPunto(this.plural, this.singular, this.color, this.icono);
  final String plural, singular;
  final Color color;
  final IconData icono;
}

/// Un punto del mapa: un servicio, producto, petición o emergencia.
class PuntoMapa {
  PuntoMapa({required this.tipo, required this.titulo, required this.punto, required this.icono, this.servicio, this.publicacion});
  final TipoPunto tipo;
  final String titulo;
  final Punto punto;
  final IconData icono;
  final Servicio? servicio;
  final Publicacion? publicacion;

  String get id => servicio?.id ?? publicacion!.id;
}

/// Reparte servicios y publicaciones en los 4 tipos del mapa.
/// Función pura para poder probarla.
List<PuntoMapa> armarPuntos({
  required List<Servicio> servicios,
  required List<Publicacion> publicaciones,
  required List<Publicacion> emergencias,
}) {
  final vistos = <String>{};
  final r = <PuntoMapa>[];
  for (final s in servicios) {
    if (s.punto == null || s.esEmergencia) continue;
    final esProducto = grupoServicio(s.categoria) == 'productos';
    r.add(PuntoMapa(
      tipo: esProducto ? TipoPunto.producto : TipoPunto.servicio,
      titulo: s.titulo,
      punto: s.punto!,
      icono: buscarCategoria(s.categoria).icono,
      servicio: s,
    ));
  }
  for (final p in emergencias) {
    if (p.punto == null || p.estado == 'resuelta' || !vistos.add(p.id)) continue;
    r.add(PuntoMapa(
      tipo: TipoPunto.emergencia,
      titulo: p.titulo,
      punto: p.punto!,
      icono: buscarCategoria(p.categoria, emergencia: true).icono,
      publicacion: p,
    ));
  }
  for (final p in publicaciones) {
    if (p.punto == null || !p.esPedido || p.esColecta || p.estado == 'resuelta' || !vistos.add(p.id)) continue;
    final esEmergencia = p.esEmergencia || p.origen == 'sos';
    r.add(PuntoMapa(
      tipo: esEmergencia ? TipoPunto.emergencia : TipoPunto.peticion,
      titulo: p.titulo,
      punto: p.punto!,
      icono: buscarCategoria(p.categoria, emergencia: esEmergencia).icono,
      publicacion: p,
    ));
  }
  return r;
}

void abrirPunto(BuildContext context, PuntoMapa p) => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            p.servicio != null ? ServicioDetalle(servicio: p.servicio!) : PublicacionDetalle(publicacion: p.publicacion!),
      ),
    );

/// Mapa del barrio (con filtros) y, debajo, "Cerca de ti" con el mismo filtro.
class MapaYCercanos extends StatefulWidget {
  const MapaYCercanos({super.key});

  @override
  State<MapaYCercanos> createState() => _MapaYCercanosState();
}

class _MapaYCercanosState extends State<MapaYCercanos> {
  final _mapa = MapController();
  TipoPunto? _filtro; // null = Todos
  PuntoMapa? _elegido;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Cargador<List<PuntoMapa>>(
      cargar: (st) async {
        final r = await Future.wait([
          st.repo.servicios(emergencia: false),
          st.repo.publicaciones(emergencia: false),
          st.repo.publicaciones(emergencia: true),
          st.repo.alertasSos(),
        ]);
        return armarPuntos(
          servicios: r[0] as List<Servicio>,
          publicaciones: r[1] as List<Publicacion>,
          emergencias: [...r[3] as List<Publicacion>, ...(r[2] as List<Publicacion>).where((p) => p.esPedido)],
        );
      },
      builder: (context, todos) {
        final ref = st.referencia;
        final conteo = {for (final t in TipoPunto.values) t: todos.where((p) => p.tipo == t).length};
        final visibles = todos.where((p) => _filtro == null || p.tipo == _filtro).toList();
        final cercanos = [...visibles]..sort((a, b) => distanciaKm(ref, a.punto).compareTo(distanciaKm(ref, b.punto)));
        final alto = (MediaQuery.of(context).size.height * 0.52).clamp(320.0, 560.0);

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Filtros
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              children: [
                _Filtro(
                  texto: 'Todos',
                  cantidad: todos.length,
                  color: Paleta.primario,
                  elegido: _filtro == null,
                  onTap: () => setState(() {
                    _filtro = null;
                    _elegido = null;
                  }),
                ),
                for (final t in TipoPunto.values)
                  _Filtro(
                    texto: t.plural,
                    cantidad: conteo[t]!,
                    color: t.color,
                    icono: t.icono,
                    elegido: _filtro == t,
                    onTap: () => setState(() {
                      _filtro = _filtro == t ? null : t;
                      _elegido = null;
                    }),
                  ),
              ],
            ),
          ),

          // ── Mapa
          Container(
            height: alto,
            margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Paleta.linea)),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              FlutterMap(
                mapController: _mapa,
                options: MapOptions(
                  initialCenter: LatLng(ref.lat, ref.lng),
                  initialZoom: st.ubicacion != null ? 14.5 : 13,
                  minZoom: 11,
                  maxZoom: 18,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                  onTap: (_, _) => setState(() => _elegido = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.alphacoders.appvecinal',
                  ),
                  MarkerLayer(markers: [
                    for (final p in visibles)
                      Marker(
                        point: LatLng(p.punto.lat, p.punto.lng),
                        width: 44,
                        height: 44,
                        child: _Pin(p, elegido: _elegido?.id == p.id, onTap: () => setState(() => _elegido = p)),
                      ),
                    if (st.ubicacion != null)
                      Marker(
                        point: LatLng(st.ubicacion!.lat, st.ubicacion!.lng),
                        width: 24,
                        height: 24,
                        child: Semantics(
                          label: 'Tu ubicación',
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2962FF),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                            ),
                          ),
                        ),
                      ),
                  ]),
                ],
              ),
              const Positioned(
                left: 8,
                bottom: 6,
                child: Text('© OpenStreetMap', style: TextStyle(fontSize: 10, color: Colors.black54)),
              ),
              if (!st.online)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFFFF3C4), borderRadius: BorderRadius.circular(10)),
                    child: const Row(children: [
                      Icon(Icons.cloud_off_rounded, size: 16, color: Colors.black87),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text('Mapa sin conexión: los puntos son de la última vez',
                            style: TextStyle(fontSize: 12, color: Colors.black87)),
                      ),
                    ]),
                  ),
                ),
              // Controles: centrar en mí y pantalla completa.
              Positioned(
                right: 10,
                top: st.online ? 10 : 48,
                child: Column(children: [
                  _BotonMapa(
                    icono: Icons.my_location_rounded,
                    tooltip: 'Centrar en mi ubicación',
                    onTap: () async {
                      await st.ubicar();
                      final u = st.ubicacion ?? st.referencia;
                      _mapa.move(LatLng(u.lat, u.lng), 15);
                    },
                  ),
                  const SizedBox(height: 8),
                  _BotonMapa(
                    icono: Icons.fullscreen_rounded,
                    tooltip: 'Ver el mapa en pantalla completa',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PantallaMapaCompleto())),
                  ),
                ]),
              ),
              if (_elegido != null)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 22,
                  child: _TarjetaPunto(_elegido!, km: distanciaKm(ref, _elegido!.punto)),
                ),
              if (visibles.isEmpty)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 22,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Text(
                      _filtro == null ? 'Todavía no hay nada publicado en el mapa.' : 'No hay ${_filtro!.plural.toLowerCase()} por ahora.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Paleta.gris),
                    ),
                  ),
                ),
            ]),
          ),

          // ── Cerca de ti
          TituloDiseno('Cerca de ti', detalle: _filtro?.plural),
          if (cercanos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('No hay nada cerca con este filtro.', style: TextStyle(color: Paleta.gris)),
            )
          else
            ListaAjustes(filas: [
              for (final p in cercanos.take(5))
                InkWell(
                  onTap: () => abrirPunto(context, p),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    child: Row(children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: p.tipo.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                        child: Icon(p.icono, size: 20, color: p.tipo.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Paleta.tinta)),
                          Text('${p.tipo.singular} · ${formatoDistancia(distanciaKm(ref, p.punto))}',
                              style: const TextStyle(fontSize: 13, color: Paleta.gris)),
                        ]),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Paleta.grisClaro),
                    ]),
                  ),
                ),
            ]),
        ]);
      },
    );
  }
}

class _Filtro extends StatelessWidget {
  const _Filtro({required this.texto, required this.cantidad, required this.color, required this.elegido, required this.onTap, this.icono});
  final String texto;
  final int cantidad;
  final Color color;
  final bool elegido;
  final VoidCallback onTap;
  final IconData? icono;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Semantics(
          button: true,
          selected: elegido,
          label: '$texto, $cantidad',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: elegido ? color : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: elegido ? color : Paleta.linea),
              ),
              child: Row(children: [
                if (icono != null) ...[
                  Icon(icono, size: 16, color: elegido ? Colors.white : color),
                  const SizedBox(width: 5),
                ],
                Text(texto,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: elegido ? Colors.white : Paleta.tinta)),
                const SizedBox(width: 6),
                Text('$cantidad',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: elegido ? Colors.white70 : Paleta.gris)),
              ]),
            ),
          ),
        ),
      );
}

class _Pin extends StatelessWidget {
  const _Pin(this.p, {required this.elegido, required this.onTap});
  final PuntoMapa p;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '${p.tipo.singular}: ${p.titulo}',
        child: GestureDetector(
          onTap: onTap,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: elegido ? 42 : 34,
              height: elegido ? 42 : 34,
              decoration: BoxDecoration(
                color: p.tipo.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black38)],
              ),
              child: Icon(p.icono, color: Colors.white, size: elegido ? 22 : 18),
            ),
          ),
        ),
      );
}

class _BotonMapa extends StatelessWidget {
  const _BotonMapa({required this.icono, required this.tooltip, required this.onTap});
  final IconData icono;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icono, color: Paleta.primario)),
      );
}

/// Tarjeta corta que sube al tocar un pin: qué es, a qué distancia y "Ver".
class _TarjetaPunto extends StatelessWidget {
  const _TarjetaPunto(this.p, {required this.km});
  final PuntoMapa p;
  final double km;

  @override
  Widget build(BuildContext context) {
    final extra = p.servicio != null
        ? (p.servicio!.vistosBuenos > 0 ? ' · ${p.servicio!.vistosBuenos} Vistos Buenos' : '')
        : (p.publicacion!.ayudantes > 0 ? ' · ${p.publicacion!.ayudantes} apoyan' : '');
    return Material(
      color: Colors.white,
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => abrirPunto(context, p),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: p.tipo.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(p.icono, color: p.tipo.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(p.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Paleta.tinta)),
                Text('${p.tipo.singular} · ${formatoDistancia(km)}$extra',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Paleta.gris)),
              ]),
            ),
            FilledButton(onPressed: () => abrirPunto(context, p), child: const Text('Ver')),
          ]),
        ),
      ),
    );
  }
}
