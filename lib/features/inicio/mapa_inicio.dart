import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../models.dart';
import '../../screens/detalles.dart';
import '../../screens/mapa.dart';
import '../../state/app_state.dart';
import '../../ui/diseno.dart';
import '../../ui/tema.dart';
import '../../ui/widgets.dart';
import '../../util.dart';
import '../emergencia/pedidos_emergencia.dart';

/// Tipos de punto del mapa del Inicio.
enum TipoPunto {
  servicio('Servicios', 'Servicio', Icons.handyman_rounded),
  producto('Productos', 'Producto', Icons.shopping_basket_rounded),
  peticion('Peticiones', 'Petición de ayuda', Icons.front_hand_rounded),
  emergencia('Emergencias', 'Emergencia', Icons.sos_rounded),
  grupo('Grupos de apoyo', 'Grupo de apoyo', Icons.health_and_safety_rounded);

  const TipoPunto(this.plural, this.singular, this.icono);
  final String plural, singular;
  // Getter (no campo) para que siga el tema claro/oscuro.
  Color get color => switch (this) {
        servicio => Paleta.ambar,
        producto => Paleta.azulInfo,
        peticion => Paleta.violeta,
        emergencia => Paleta.rojo,
        grupo => const Color(0xFF0E7490),
      };
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
    if (s.punto == null) continue;
    final esProducto = grupoServicio(s.categoria) == 'productos';
    r.add(PuntoMapa(
      tipo: s.esEmergencia ? TipoPunto.grupo : (esProducto ? TipoPunto.producto : TipoPunto.servicio),
      titulo: s.titulo,
      punto: s.punto!,
      icono: buscarCategoria(s.categoria, emergencia: s.esEmergencia).icono,
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

/// Puntos del mapa en emergencia: SOLO lo de esta emergencia.
///   - Necesitan ayuda: pedidos y SOS creados desde que se activó [desde].
///   - Puntos de ayuda: grupos de apoyo con ubicación.
/// Función pura para poder probarla.
List<PuntoMapa> armarPuntosEmergencia({
  required List<Servicio> grupos,
  required List<Publicacion> pedidos,
  DateTime? desde,
}) =>
    armarPuntos(
      servicios: [for (final g in grupos) if (g.esEmergencia) g],
      publicaciones: const [],
      emergencias: [
        for (final p in pedidos)
          if (p.esPedido && (desde == null || !p.creado.isBefore(desde.toLocal()))) p,
      ],
    );

/// Nombre del tipo según el modo: en emergencia se habla de quién necesita
/// ayuda y de puntos de ayuda.
String nombreTipo(TipoPunto t, {required bool emergencia, bool plural = false}) {
  if (emergencia && t == TipoPunto.emergencia) return plural ? 'Necesitan ayuda' : 'Necesita ayuda';
  if (emergencia && t == TipoPunto.grupo) return plural ? 'Puntos de ayuda' : 'Punto de ayuda';
  return plural ? t.plural : t.singular;
}

void abrirPunto(BuildContext context, PuntoMapa p) {
  if (p.tipo == TipoPunto.grupo && p.servicio != null) {
    abrirPuntoDeAyuda(context, p.servicio!);
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          p.servicio != null ? ServicioDetalle(servicio: p.servicio!) : PublicacionDetalle(publicacion: p.publicacion!),
    ),
  );
}

/// Punto de ayuda (albergue, posta, centro de acopio...): llamar, cómo llegar
/// o pedirle ayuda directamente.
Future<void> abrirPuntoDeAyuda(BuildContext context, Servicio g) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _HojaPuntoDeAyuda(g),
    );

class _HojaPuntoDeAyuda extends StatelessWidget {
  const _HojaPuntoDeAyuda(this.g);
  final Servicio g;

  Future<void> _abrir(Uri u) async {
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {
      avisar('No se pudo abrir.');
    }
  }

  Future<void> _pedir(BuildContext context) async {
    final st = context.read<AppState>();
    if (!st.logueado) {
      avisar('Para escribirle al grupo necesitas una cuenta. Mientras tanto, llámalos o ve directamente.');
      return;
    }
    final detalle = await showDialog<String>(context: context, builder: (_) => _DialogoPedido(g.titulo));
    if (detalle == null || !context.mounted) return;
    try {
      await st.repo.crearPedidoServicio({
        'id': nuevoId(),
        'servicio_id': g.id,
        'prestador_id': g.autorId,
        'cliente_nombre': st.nombre,
        'cliente_telefono': st.perfil?['telefono'],
        'cliente_sector': st.sector,
        'detalle': detalle,
        'estado': 'pendiente',
      });
      if (context.mounted) Navigator.pop(context);
      avisar('Listo. ${g.titulo} recibió tu pedido de ayuda.');
    } catch (e) {
      avisar(traducirError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final km = g.punto == null ? null : distanciaKm(st.referencia, g.punto!);
    final cat = buscarCategoria(g.categoria, emergencia: true);
    final tel = g.telefono?.trim();
    final puedePedir = g.autorId != null && g.autorId != st.uid;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: TipoPunto.grupo.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(cat.icono, color: TipoPunto.grupo.color, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.titulo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Paleta.tinta)),
                Text([cat.nombre, if (km != null) formatoDistancia(km)].join(' · '),
                    style: TextStyle(fontSize: 14, color: Paleta.gris)),
              ]),
            ),
          ]),
          if (g.descripcion != null && g.descripcion!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(g.descripcion!, style: TextStyle(fontSize: 14, color: Paleta.tinta)),
          ],
          if (g.horario != null && g.horario!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.schedule_rounded, size: 16, color: Paleta.gris),
              const SizedBox(width: 4),
              Expanded(child: Text(g.horario!, style: TextStyle(fontSize: 13, color: Paleta.gris))),
            ]),
          ],
          const SizedBox(height: 16),
          Row(children: [
            if (tel != null && tel.isNotEmpty) ...[
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => _abrir(Uri.parse('tel:${tel.replaceAll(RegExp(r'[^0-9+]'), '')}')),
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Llamar'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (g.punto != null)
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _abrir(Uri.parse(
                        'https://www.google.com/maps/dir/?api=1&destination=${g.punto!.lat},${g.punto!.lng}&travelmode=walking')),
                    icon: const Icon(Icons.directions_walk_rounded),
                    label: const Text('Cómo llegar'),
                  ),
                ),
              ),
          ]),
          if (puedePedir) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Paleta.rojo),
                onPressed: () => _pedir(context),
                icon: const Icon(Icons.front_hand_rounded),
                label: const Text('Pedir ayuda a este grupo'),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _DialogoPedido extends StatefulWidget {
  const _DialogoPedido(this.grupo);
  final String grupo;

  @override
  State<_DialogoPedido> createState() => _DialogoPedidoState();
}

class _DialogoPedidoState extends State<_DialogoPedido> {
  final _texto = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Pedir ayuda a ${widget.grupo}'),
        content: TextField(
          controller: _texto,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: 300,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: 'Ej: Somos 4, necesitamos donde dormir esta noche', errorText: _error),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Paleta.rojo),
            onPressed: () {
              final t = _texto.text.trim();
              if (t.length < 2) {
                setState(() => _error = 'Cuéntales en pocas palabras qué necesitas.');
                return;
              }
              Navigator.pop(context, t);
            },
            child: const Text('Enviar'),
          ),
        ],
      );
}

/// Mapa del barrio (con filtros) y, debajo, "Cerca de ti" con el mismo filtro.
class MapaYCercanos extends StatefulWidget {
  const MapaYCercanos({super.key, this.emergencia = false});

  /// En emergencia: suma los grupos de apoyo y empieza filtrado en Emergencias.
  final bool emergencia;

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
      claves: [widget.emergencia, st.emergencia.clave],
      cargar: (st) async {
        if (widget.emergencia) {
          final r = await Future.wait([
            st.repo.servicios(emergencia: true),
            st.repo.publicaciones(emergencia: true),
            st.repo.alertasSos(),
          ]);
          return armarPuntosEmergencia(
            grupos: r[0] as List<Servicio>,
            pedidos: [...r[2] as List<Publicacion>, ...r[1] as List<Publicacion>],
            desde: st.emergencia.desde,
          );
        }
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
        final alto = (MediaQuery.of(context).size.height * 0.32).clamp(220.0, 300.0);

        return Container(
          margin: EdgeInsets.only(top: widget.emergencia ? 0 : 14),
          padding: EdgeInsets.only(top: widget.emergencia ? 4 : 16, bottom: 18),
          // Fondo cálido suave: separa la sección sin cortes bruscos.
          color: Paleta.seccion,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Introducción al mapa
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // En emergencia el título ya está en la cabecera: solo la explicación.
              if (!widget.emergencia) ...[
                Text('Explora tu barrio',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Paleta.tinta)),
                const SizedBox(height: 2),
              ],
              Text(
                  widget.emergencia
                      ? 'En rojo, vecinos que piden ayuda ahora. En celeste, puntos de ayuda (albergues, postas). Toca uno para actuar.'
                      : 'Servicios, productos, vecinos que piden ayuda y emergencias cerca de ti. Toca un punto para ver más.',
                  style: TextStyle(fontSize: 14, color: Paleta.gris, height: 1.3)),
            ]),
          ),
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
                for (final t in TipoPunto.values.where((t) => widget.emergencia
                    ? t == TipoPunto.emergencia || t == TipoPunto.grupo
                    : t != TipoPunto.grupo))
                  _Filtro(
                    texto: nombreTipo(t, emergencia: widget.emergencia, plural: true),
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              FlutterMap(
                mapController: _mapa,
                options: MapOptions(
                  initialCenter: LatLng(ref.lat, ref.lng),
                  initialZoom: st.ubicacion != null ? 14.5 : 13,
                  minZoom: 11,
                  maxZoom: 18,
                  // Con un dedo se desplaza la pantalla; el mapa se mueve y amplía con dos dedos
                  // (o en pantalla completa). Así el mapa no "atrapa" el desplazamiento.
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.pinchMove | InteractiveFlag.doubleTapZoom,
                  ),
                  onTap: (_, _) => setState(() => _elegido = null),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.alphacoders.appvecinal',
                    tileBuilder: Paleta.oscuro ? darkModeTileBuilder : null, // mapa oscuro en modo oscuro
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
                              color: Paleta.azulInfo,
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
              Positioned(
                left: 8,
                bottom: 6,
                child: Text('© OpenStreetMap', style: TextStyle(fontSize: 10, color: Paleta.gris)),
              ),
              if (!st.online)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Paleta.ambarSuave, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Icon(Icons.cloud_off_rounded, size: 16, color: Paleta.tinta),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text('Mapa sin conexión: los puntos son de la última vez',
                            style: TextStyle(fontSize: 12, color: Paleta.tinta)),
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
                  child: _TarjetaPunto(_elegido!, km: distanciaKm(ref, _elegido!.punto), emergencia: widget.emergencia),
                ),
              if (visibles.isEmpty)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 22,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Paleta.superficie, borderRadius: BorderRadius.circular(14)),
                    child: Text(
                      _filtro == null ? (widget.emergencia ? 'Aún no hay pedidos ni puntos de ayuda en esta emergencia.' : 'Todavía no hay nada publicado en el mapa.') : (widget.emergencia ? 'Nada por ahora en esta emergencia.' : 'No hay ${_filtro!.plural.toLowerCase()} por ahora.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Paleta.gris),
                    ),
                  ),
                ),
            ]),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(children: [
              Icon(Icons.pinch_outlined, size: 15, color: Paleta.gris),
              SizedBox(width: 5),
              Expanded(
                child: Text('Usa dos dedos para mover el mapa, o ábrelo en pantalla completa.',
                    style: TextStyle(fontSize: 12, color: Paleta.gris)),
              ),
            ]),
          ),

          // ── Cerca de ti
          TituloDiseno(
            'Cerca de ti',
            detalle: widget.emergencia || _filtro == null ? null : nombreTipo(_filtro!, emergencia: false, plural: true),
            // En emergencia: todos los pedidos de ayuda, en una lista aparte.
            accion: widget.emergencia && conteo[TipoPunto.emergencia]! > 0
                ? (
                    'Todos los pedidos (${conteo[TipoPunto.emergencia]})',
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PedidosEmergenciaScreen())),
                  )
                : null,
          ),
          if (cercanos.isEmpty)
            Padding(
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
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Paleta.tinta)),
                          Text(['${nombreTipo(p.tipo, emergencia: widget.emergencia)} · ${formatoDistancia(distanciaKm(ref, p.punto))}', if (p.publicacion?.sector != null) p.publicacion!.sector!].join(' · '),
                              style: TextStyle(fontSize: 13, color: Paleta.gris)),
                        ]),
                      ),
                      Icon(Icons.chevron_right_rounded, color: Paleta.grisClaro),
                    ]),
                  ),
                ),
            ]),
          ]),
        );
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
                color: elegido ? color : Paleta.superficie,
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
        color: Paleta.superficie,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icono, color: Paleta.primario)),
      );
}

/// Tarjeta corta que sube al tocar un pin: qué es, a qué distancia y "Ver".
class _TarjetaPunto extends StatelessWidget {
  const _TarjetaPunto(this.p, {required this.km, this.emergencia = false});
  final bool emergencia;
  final PuntoMapa p;
  final double km;

  @override
  Widget build(BuildContext context) {
    final extra = p.servicio != null
        ? (p.servicio!.vistosBuenos > 0 ? ' · ${p.servicio!.vistosBuenos} Vistos Buenos' : '')
        : (p.publicacion!.ayudantes > 0 ? ' · ${p.publicacion!.ayudantes} apoyan' : '');
    return Material(
      color: Paleta.superficie,
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
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Paleta.tinta)),
                Text('${nombreTipo(p.tipo, emergencia: emergencia)} · ${formatoDistancia(km)}$extra',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Paleta.gris)),
              ]),
            ),
            FilledButton(onPressed: () => abrirPunto(context, p), child: const Text('Ver')),
          ]),
        ),
      ),
    );
  }
}
