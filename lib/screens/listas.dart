import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../features/sos/sos_alertas.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/diseno.dart';
import '../ui/tema.dart';
import '../ui/widgets.dart';
import '../util.dart';
import 'confianza.dart';
import 'mapa.dart';

// ======================================= Módulo 1 · Servicios de Proximidad

class ServiciosScreen extends StatefulWidget {
  const ServiciosScreen({super.key, required this.emergencia, this.grupoInicial, this.consultaInicial});
  final bool emergencia;
  final String? grupoInicial; // servicios | productos | clases
  final String? consultaInicial;

  @override
  State<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends State<ServiciosScreen> {
  late final TextEditingController _buscar = TextEditingController(text: widget.consultaInicial ?? '');
  late String _busqueda = (widget.consultaInicial ?? '').toLowerCase();
  late String _filtro = widget.grupoInicial ?? 'todos';
  /// Por defecto, lo más cerca de tu casa (y entre lo cercano, lo más
  /// recomendado). "Más recomendados" ordena solo por Visto Bueno.
  bool _porCercania = true;

  /// Hasta esta distancia se considera "cerca de ti" (se llega a pie).
  static const _radioCercaKm = 2.0;

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  bool _pasaFiltro(Servicio s) {
    if (_filtro == 'todos') return true;
    if (widget.emergencia) return s.categoria == _filtro;
    return grupoServicio(s.categoria) == _filtro;
  }

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    final e = widget.emergencia;
    final opciones = e
        ? [('todos', 'Todos'), for (final c in categoriasApoyo) (c.id, c.nombre)]
        : const [('todos', 'Todos'), ('servicios', 'Servicios'), ('productos', 'Productos'), ('clases', 'Clases')];

    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: Cargador<List<Servicio>>(
        claves: [e],
        cargar: (st) => st.repo.servicios(emergencia: e),
        builder: (context, todos) {
          final ref = context.read<AppState>().referencia;
          final lista = todos.where((s) {
            if (!_pasaFiltro(s)) return false;
            if (_busqueda.isEmpty) return true;
            final texto = '${s.titulo} ${s.descripcion ?? ''} ${s.autorNombre ?? ''} '
                    '${buscarCategoria(s.categoria).nombre} ${s.sector ?? ''}'
                .toLowerCase();
            return texto.contains(_busqueda);
          }).toList();
          double d(Servicio s) => s.punto == null ? 999 : distanciaKm(ref, s.punto!);
          double dr(Servicio s) => s.punto == null ? 999 : distanciaKmRedondeada(ref, s.punto!);
          // Puntaje de confianza vecinal: pesa más quien está verificado,
          // quien vive en tu zona y lo más reciente.
          final puntajes = {for (final s in lista) s.id: s.puntaje(st.sector)};
          int masRecomendado(Servicio a, Servicio b) {
            final z = puntajes[b.id]!.compareTo(puntajes[a.id]!);
            return z != 0 ? z : b.vistosBuenos.compareTo(a.vistosBuenos);
          }
          // "El más recomendado" se calcula con todos los del barrio, no solo
          // con lo filtrado, para que el trofeo no cambie al buscar.
          final destacados = e ? const <String>{} : masRecomendadosPorTipo(todos, st.sector);
          lista.sort(_porCercania
              // Cerca primero; a distancia parecida, el más recomendado.
              ? (a, b) {
                  final c = dr(a).compareTo(dr(b));
                  return c != 0 ? c : masRecomendado(a, b);
                }
              : (a, b) {
                  final c = masRecomendado(a, b);
                  return c != 0 ? c : d(a).compareTo(d(b));
                });
          final cerca = _porCercania ? lista.where((s) => d(s) <= _radioCercaKm).toList() : lista;
          final lejos = _porCercania ? lista.where((s) => d(s) > _radioCercaKm).toList() : const <Servicio>[];
          final zona = st.ubicacion != null ? 'tu ubicación' : (st.sector ?? Zona.nombre);

          return ListView(padding: const EdgeInsets.only(bottom: 110), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: CajaBusqueda(
                controller: _buscar,
                pista: e ? 'Ej: albergue, primeros auxilios' : 'Ej: gasfitero, pan, clases',
                etiqueta: e ? 'Buscar grupo de apoyo' : 'Buscar servicios o productos',
                onChanged: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
              ),
            ),
            FilaPildoras(opciones: opciones, seleccion: _filtro, onCambio: (v) => setState(() => _filtro = v)),
            // Una sola fila de controles: cómo ordenar y ver en el mapa.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    // Sin íconos: así el texto cabe en una línea aun con letra grande.
                    segments: const [
                      ButtonSegment(value: true, label: Text('Cerca de mí', maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ButtonSegment(value: false, label: Text('Recomendados', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                    selected: {_porCercania},
                    onSelectionChanged: (v) => setState(() => _porCercania = v.first),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Ver en el mapa',
                  style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PantallaMapaCompleto()),
                  ),
                  icon: const Icon(Icons.map_outlined),
                ),
              ]),
            ),
            if (lista.isEmpty)
              EstadoVacio(
                icono: Icons.search_off,
                texto: e
                    ? 'No hay grupos de apoyo con ese filtro.'
                    : 'No encontramos eso en tu barrio todavía.\n¿Conoces a alguien bueno? Invítalo a publicarse.',
              )
            else if (_porCercania) ...[
              _TituloGrupo(
                cerca.isEmpty ? 'Nada a menos de 2 km' : 'Cerca de ti',
                cerca.isEmpty
                    ? 'Te mostramos lo más cercano a $zona.'
                    : 'A menos de 2 km de $zona · ${cerca.length} ${cerca.length == 1 ? 'opción' : 'opciones'}',
              ),
              for (final s in cerca) TarjetaMercado(s, destacado: destacados.contains(s.id)),
              if (lejos.isNotEmpty) ...[
                if (cerca.isNotEmpty) const _TituloGrupo('Un poco más lejos', 'Más de 2 km, por si no encuentras cerca.'),
                for (final s in lejos) TarjetaMercado(s, destacado: destacados.contains(s.id)),
              ],
            ] else ...[
              _TituloGrupo('Los más recomendados',
                  'Por la confianza de tus vecinos: verificados, de tu zona y recientes · ${lista.length} ${lista.length == 1 ? 'opción' : 'opciones'}'),
              for (final s in lista) TarjetaMercado(s, destacado: destacados.contains(s.id)),
            ],
          ]);
        },
      ),
    );
  }
}

// ============================ Módulo 2 · Cadena de Favores / Tablero humanitario

class FavoresScreen extends StatefulWidget {
  const FavoresScreen({super.key, required this.emergencia});
  final bool emergencia;

  @override
  State<FavoresScreen> createState() => _FavoresScreenState();
}

/// Estructura (una idea por bloque):
///   1. Banner + DOS caminos claros: "Necesito una mano" / "Quiero dar algo"
///   2. Colectas del barrio (si hay)
///   3. Solicitudes: filtro simple Todo / Necesitan / Ofrecen
///   4. Reconocimiento: vecinos que más ayudan (al final)
class _FavoresScreenState extends State<FavoresScreen> {
  String _tipo = 'todos';
  bool _porCercania = false;

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    final e = widget.emergencia;

    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: Cargador<List<Publicacion>>(
        claves: [e],
        cargar: (st) => st.repo.publicaciones(emergencia: e),
        builder: (context, todas) {
          final ref = context.read<AppState>().referencia;
          final colectas = e ? <Publicacion>[] : (todas.where((p) => p.esColecta).toList()..sort((a, b) => b.progreso.compareTo(a.progreso)));
          final lista = todas.where((p) => (e || !p.esColecta) && (_tipo == 'todos' || p.tipo == _tipo)).toList();
          double d(Publicacion p) => p.punto == null ? 999 : distanciaKm(ref, p.punto!);
          lista.sort((a, b) {
            if (e) {
              final c = b.pesoPrioridad.compareTo(a.pesoPrioridad);
              if (c != 0) return c;
            }
            return _porCercania ? d(a).compareTo(d(b)) : b.creado.compareTo(a.creado);
          });

          return ListView(padding: const EdgeInsets.only(bottom: 110), children: [
            // 0 ─ Alertas SOS (día a día; en emergencia ya están en el tablero)
            if (!e) const FranjaAlertasSos(maximo: 3),
            // 1 ─ Banner (día a día). En emergencia la lista va directo: pedir
            // ayuda y compartir ya están en la pestaña Emergencia.
            if (!e)
              const BannerDegradado(
                icono: Icons.favorite_border,
                titulo: 'Una pequeña ayuda cambia el día',
                subtitulo: 'Entre vecinos, sin dinero de por medio.',
                colores: [Paleta.acentoOscuro, Paleta.acento],
                colorIcono: Colors.white,
              ),
            if (e)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Text('Los más urgentes aparecen primero. Toca uno para ayudar o ver cómo contactar.',
                    style: TextStyle(fontSize: 14, color: Paleta.gris)),
              ),
            Center(
              child: TextButton.icon(
                onPressed: () => mostrarConsejos(context),
                icon: const Icon(Icons.shield_outlined, size: 20),
                label: const Text('Cómo ayudar con seguridad'),
              ),
            ),

            // 2 ─ Colectas
            if (colectas.isNotEmpty) ...[
              const TituloDiseno('Eventos solidarios', ceja: 'Responsabilidad social'),
              SizedBox(
                height: 206,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [for (final c in colectas) TarjetaColecta(c)],
                ),
              ),
            ],

            // 3 ─ Solicitudes
            TituloDiseno(
              e ? 'Pedidos y lo que hay para compartir' : 'Solicitudes de vecinos',
              detalle: '${lista.length}',
            ),
            Row(children: [
              Expanded(
                child: FilaPildoras(
                  opciones: [('todos', 'Todo'), ('pido', 'Necesitan'), ('ofrezco', e ? 'Para compartir' : 'Ofrecen')],
                  seleccion: _tipo,
                  onCambio: (v) => setState(() => _tipo = v),
                ),
              ),
              IconButton(
                tooltip: _porCercania ? 'Ver lo más reciente primero' : 'Ver lo más cerca primero',
                onPressed: () => setState(() => _porCercania = !_porCercania),
                icon: Icon(_porCercania ? Icons.schedule : Icons.near_me_outlined),
              ),
              const SizedBox(width: 4),
            ]),
            const SizedBox(height: 4),
            if (lista.isEmpty)
              EstadoVacio(
                icono: e ? Icons.health_and_safety : Icons.diversity_3,
                texto: e ? 'Por ahora no hay nada aquí.' : 'Todavía no hay solicitudes. ¿Te falta algo? Toca Publicar → Pedir apoyo.',
              )
            else
              for (final p in lista) TarjetaPublicacion(p),

            // 4 ─ Reconocimiento
            if (!e)
              Cargador<List<Map<String, dynamic>>>(
                cargar: (st) => st.repo.vecinosDestacados(),
                builder: (c, destacados) {
                  if (destacados.isEmpty) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const TituloDiseno('Vecinos que más ayudan', ceja: 'Reconocimiento'),
                    ListaAjustes(filas: [
                      for (final d in destacados)
                        () {
                          final n = (d['ayudas_confirmadas'] as num?)?.toInt() ?? 0;
                          final nivel = Nivel.de(n);
                          return FilaAjuste(
                            icono: Icons.emoji_events_outlined,
                            texto: (d['nombre'] ?? 'Vecino') as String,
                            valor: '${nivel.corto} · $n ${n == 1 ? 'ayuda' : 'ayudas'}',
                          );
                        }(),
                    ]),
                  ]);
                },
              ),
          ]);
        },
      ),
    );
  }
}

/// Título de un grupo de la lista: "Cerca de ti", "Un poco más lejos"...
class _TituloGrupo extends StatelessWidget {
  const _TituloGrupo(this.titulo, this.detalle);
  final String titulo, detalle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
            header: true,
            child: Text(titulo, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19)),
          ),
          const SizedBox(height: 2),
          Text(detalle, style: const TextStyle(color: Paleta.gris, fontSize: 14)),
        ]),
      );
}
