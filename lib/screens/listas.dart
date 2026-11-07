import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/diseno.dart';
import '../ui/tema.dart';
import '../ui/widgets.dart';
import '../util.dart';
import 'confianza.dart';

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
  bool _porCercania = false;

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
          lista.sort(_porCercania ? (a, b) => d(a).compareTo(d(b)) : (a, b) => b.vistosBuenos.compareTo(a.vistosBuenos));

          return ListView(padding: const EdgeInsets.only(bottom: 110), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: CajaBusqueda(
                controller: _buscar,
                pista: e ? 'Ej: albergue, primeros auxilios' : 'Buscar servicios o productos',
                etiqueta: e ? 'Buscar grupo de apoyo' : 'Buscar servicios o productos',
                onChanged: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
              ),
            ),
            FilaPildoras(opciones: opciones, seleccion: _filtro, onCambio: (v) => setState(() => _filtro = v)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(_porCercania ? 'Más cerca de ti' : 'Recomendados',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19)),
                  ),
                ),
                Text('${lista.length} ${lista.length == 1 ? 'resultado' : 'resultados'}',
                    style: const TextStyle(color: Paleta.gris, fontSize: 13)),
                IconButton(
                  tooltip: _porCercania ? 'Ordenar por recomendaciones' : 'Ordenar por cercanía',
                  onPressed: () => setState(() => _porCercania = !_porCercania),
                  icon: Icon(_porCercania ? Icons.thumb_up_outlined : Icons.near_me_outlined),
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
            else
              Cuadricula2(hijos: [for (final s in lista) TarjetaMercado(s)]),
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

class _FavoresScreenState extends State<FavoresScreen> {
  String _tipo = 'todos';
  String? _categoria;
  bool _porCercania = false;

  @override
  void didUpdateWidget(covariant FavoresScreen old) {
    super.didUpdateWidget(old);
    if (old.emergencia != widget.emergencia) _categoria = null;
  }

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    final e = widget.emergencia;
    final cats = e ? categoriasEmergencia : categoriasFavor;
    final bienvenida = e
        ? 'Aquí ves a quién le falta algo y qué cosas hay para compartir. Si puedes, responde: cada ayuda cuenta.'
        : 'Aquí nos ayudamos entre vecinos, sin dinero de por medio. Pide lo que te falta o da lo que te sobra.';

    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: Cargador<List<Publicacion>>(
        claves: [e],
        cargar: (st) => st.repo.publicaciones(emergencia: e),
        builder: (context, todas) {
          final ref = context.read<AppState>().referencia;
          final colectas = e ? <Publicacion>[] : (todas.where((p) => p.esColecta).toList()..sort((a, b) => b.progreso.compareTo(a.progreso)));
          final verColectasEnLista = _categoria == 'colecta';
          final lista = todas
              .where((p) =>
                  (verColectasEnLista || !p.esColecta || e) &&
                  (_tipo == 'todos' || p.tipo == _tipo) &&
                  (_categoria == null || p.categoria == _categoria))
              .toList();
          double d(Publicacion p) => p.punto == null ? 999 : distanciaKm(ref, p.punto!);
          lista.sort((a, b) {
            if (e) {
              final c = b.pesoPrioridad.compareTo(a.pesoPrioridad);
              if (c != 0) return c;
            }
            return _porCercania ? d(a).compareTo(d(b)) : b.creado.compareTo(a.creado);
          });

          return ListView(padding: const EdgeInsets.only(bottom: 110), children: [
            // Bienvenida (banner terracota del diseño)
            BannerDegradado(
              icono: e ? Icons.volunteer_activism : Icons.favorite_border,
              titulo: e ? 'Cada ayuda cuenta' : 'Una pequeña ayuda cambia el día',
              subtitulo: bienvenida,
              colores: e ? const [Color(0xFFB71C1C), Color(0xFFD84343)] : const [Paleta.terracota1, Paleta.terracota2],
              colorIcono: Colors.white,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                TextButton.icon(
                  onPressed: () => mostrarConsejos(context),
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('Ayudar con seguridad'),
                ),
                const Spacer(),
                BotonEscuchar(bienvenida, compacto: true),
              ]),
            ),

            // Colectas activas
            if (colectas.isNotEmpty && _categoria == null && _tipo != 'ofrezco') ...[
              const TituloDiseno('Colectas del barrio', ceja: 'Responsabilidad social'),
              SizedBox(
                height: 206,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [for (final c in colectas) TarjetaColecta(c)],
                ),
              ),
            ],

            // Reconocimiento público
            if (!e && _categoria == null && _tipo == 'todos')
              Cargador<List<Map<String, dynamic>>>(
                cargar: (st) => st.repo.vecinosDestacados(),
                builder: (c, destacados) {
                  if (destacados.isEmpty) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const TituloDiseno('Vecinos que más ayudan', ceja: 'Reconocimiento'),
                    SizedBox(
                      height: 112,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children: [
                          for (final d in destacados)
                            () {
                              final n = (d['ayudas_confirmadas'] as num?)?.toInt() ?? 0;
                              final nivel = Nivel.de(n);
                              return Semantics(
                                label: '${d['nombre']}, ${nivel.nombre}, $n ayudas confirmadas',
                                excludeSemantics: true,
                                child: Card(
                                  color: const Color(0xFFFFF8E1),
                                  child: Container(
                                    width: 150,
                                    padding: const EdgeInsets.all(10),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(nivel.emoji, style: const TextStyle(fontSize: 26)),
                                      Text((d['nombre'] ?? 'Vecino') as String,
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                                      Text('$n ${n == 1 ? 'ayuda' : 'ayudas'} · ${d['sector'] ?? ''}',
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.black87, fontSize: 12)),
                                    ]),
                                  ),
                                ),
                              );
                            }(),
                        ],
                      ),
                    ),
                  ]);
                },
              ),

            // Filtros
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 4),
              child: Row(children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(e ? 'Pedidos y recursos' : 'Solicitudes recientes',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19)),
                  ),
                ),
                Text('${lista.length} cerca', style: const TextStyle(color: Paleta.gris, fontSize: 13)),
                IconButton(
                  tooltip: _porCercania ? 'Ordenar por lo más reciente' : 'Ordenar por lo más cerca',
                  onPressed: () => setState(() => _porCercania = !_porCercania),
                  icon: Icon(_porCercania ? Icons.schedule : Icons.near_me_outlined),
                ),
              ]),
            ),
            FilaPildoras(
              opciones: [('todos', 'Todo'), ('pido', e ? 'Necesitan ayuda' : 'Necesitan'), ('ofrezco', e ? 'Para compartir' : 'Ofrecen')],
              seleccion: _tipo,
              onCambio: (v) => setState(() => _tipo = v),
            ),
            SelectorCategorias(categorias: cats, seleccion: _categoria, onCambio: (c) => setState(() => _categoria = c)),

            // Publicaciones
            if (lista.isEmpty)
              EstadoVacio(
                icono: e ? Icons.health_and_safety : Icons.diversity_3,
                texto: e
                    ? 'Por ahora no hay nada aquí. Si alguien necesita ayuda, publícalo con el botón de abajo.'
                    : 'Todavía no hay nada aquí. ¿Te falta algo o quieres regalar algo? Toca "Publicar".',
              )
            else
              for (final p in lista) TarjetaPublicacion(p),
          ]);
        },
      ),
    );
  }
}

