import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';
import '../util.dart';
import 'confianza.dart';

// ======================================= Módulo 1 · Servicios de Proximidad

class ServiciosScreen extends StatefulWidget {
  const ServiciosScreen({super.key, required this.emergencia});
  final bool emergencia;

  @override
  State<ServiciosScreen> createState() => _ServiciosScreenState();
}

class _ServiciosScreenState extends State<ServiciosScreen> {
  String _busqueda = '';
  String? _categoria;
  bool _porCercania = false;

  @override
  void didUpdateWidget(covariant ServiciosScreen old) {
    super.didUpdateWidget(old);
    if (old.emergencia != widget.emergencia) _categoria = null;
  }

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    final cats = widget.emergencia ? categoriasApoyo : categoriasServicio;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: TextField(
          onChanged: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            labelText: widget.emergencia ? 'Buscar grupo de apoyo' : 'Buscar servicio o producto',
            hintText: widget.emergencia ? 'Ej: albergue, primeros auxilios' : 'Ej: gasfitero, pan, bodega, clases',
          ),
        ),
      ),
      SelectorCategorias(categorias: cats, seleccion: _categoria, onCambio: (c) => setState(() => _categoria = c)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, icon: Icon(Icons.thumb_up), label: Text('Recomendados')),
            ButtonSegment(value: true, icon: Icon(Icons.near_me), label: Text('Más cerca')),
          ],
          selected: {_porCercania},
          onSelectionChanged: (s) => setState(() => _porCercania = s.first),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async => st.refrescar(),
          child: Cargador<List<Servicio>>(
            claves: [widget.emergencia],
            cargar: (st) => st.repo.servicios(emergencia: widget.emergencia),
            builder: (context, todos) {
              final ref = context.read<AppState>().referencia;
              final lista = todos.where((s) {
                if (_categoria != null && s.categoria != _categoria) return false;
                if (_busqueda.isEmpty) return true;
                final texto = '${s.titulo} ${s.descripcion ?? ''} ${s.autorNombre ?? ''} '
                        '${buscarCategoria(s.categoria).nombre} ${s.sector ?? ''}'
                    .toLowerCase();
                return texto.contains(_busqueda);
              }).toList();
              double d(Servicio s) => s.punto == null ? 999 : distanciaKm(ref, s.punto!);
              lista.sort(_porCercania
                  ? (a, b) => d(a).compareTo(d(b))
                  : (a, b) => b.vistosBuenos.compareTo(a.vistosBuenos));
              if (lista.isEmpty) {
                return ListView(children: [
                  EstadoVacio(
                    icono: Icons.search_off,
                    texto: widget.emergencia
                        ? 'No hay grupos de apoyo con ese filtro.'
                        : 'No encontramos ese servicio en tu barrio todavía.\n¿Conoces a alguien bueno? Invítalo a publicarse.',
                  ),
                ]);
              }
              return ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 96),
                itemCount: lista.length,
                itemBuilder: (_, i) => TarjetaServicio(lista[i]),
              );
            },
          ),
        ),
      ),
    ]);
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

          return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
            // Bienvenida
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(bienvenida, style: Theme.of(context).textTheme.titleMedium)),
                BotonEscuchar(bienvenida, compacto: true),
              ]),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextButton.icon(
                  onPressed: () => mostrarConsejos(context),
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('Consejos para ayudar con seguridad'),
                ),
              ),
            ),

            // Colectas activas
            if (colectas.isNotEmpty && _categoria == null && _tipo != 'ofrezco') ...[
              const TituloSeccion('Colectas del barrio'),
              SizedBox(
                height: 196,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [for (final c in colectas) TarjetaColecta(c)],
                ),
              ),
            ],

            // Filtros
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: SegmentedButton<String>(
                segments: [
                  const ButtonSegment(value: 'todos', label: Text('Todo')),
                  ButtonSegment(value: 'pido', icon: const Icon(Icons.front_hand), label: Text(e ? 'Necesitan ayuda' : 'Necesitan')),
                  ButtonSegment(value: 'ofrezco', icon: const Icon(Icons.volunteer_activism), label: Text(e ? 'Para compartir' : 'Ofrecen')),
                ],
                selected: {_tipo},
                onSelectionChanged: (s) => setState(() => _tipo = s.first),
              ),
            ),
            SelectorCategorias(categorias: cats, seleccion: _categoria, onCambio: (c) => setState(() => _categoria = c)),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: FilterChip(
                  avatar: const Icon(Icons.near_me, size: 18),
                  label: const Text('Lo más cerca primero'),
                  selected: _porCercania,
                  onSelected: (v) => setState(() => _porCercania = v),
                ),
              ),
            ),

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

