import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';
import '../util.dart';

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
            labelText: widget.emergencia ? 'Buscar grupo de apoyo' : 'Buscar un oficio o servicio',
            hintText: widget.emergencia ? 'Ej: albergue, primeros auxilios' : 'Ej: gasfitero, clases, cerrajero',
          ),
        ),
      ),
      SelectorCategorias(categorias: cats, seleccion: _categoria, onCambio: (c) => setState(() => _categoria = c)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, icon: Icon(Icons.thumb_up), label: Text('Más recomendados')),
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
    final cats = widget.emergencia ? categoriasEmergencia : categoriasFavor;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: SegmentedButton<String>(
          segments: [
            const ButtonSegment(value: 'todos', label: Text('Todo')),
            ButtonSegment(value: 'pido', icon: const Icon(Icons.front_hand), label: Text(widget.emergencia ? 'Necesitan' : 'Piden')),
            ButtonSegment(value: 'ofrezco', icon: const Icon(Icons.volunteer_activism), label: Text(widget.emergencia ? 'Ofrecen' : 'Ofrecen')),
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
            label: const Text('Más cerca primero'),
            selected: _porCercania,
            onSelected: (v) => setState(() => _porCercania = v),
          ),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async => st.refrescar(),
          child: Cargador<List<Publicacion>>(
            claves: [widget.emergencia],
            cargar: (st) => st.repo.publicaciones(emergencia: widget.emergencia),
            builder: (context, todas) {
              final ref = context.read<AppState>().referencia;
              final lista = todas
                  .where((p) => (_tipo == 'todos' || p.tipo == _tipo) && (_categoria == null || p.categoria == _categoria))
                  .toList();
              double d(Publicacion p) => p.punto == null ? 999 : distanciaKm(ref, p.punto!);
              lista.sort((a, b) {
                if (widget.emergencia) {
                  final c = b.pesoPrioridad.compareTo(a.pesoPrioridad);
                  if (c != 0) return c;
                }
                return _porCercania ? d(a).compareTo(d(b)) : b.creado.compareTo(a.creado);
              });
              if (lista.isEmpty) {
                return ListView(children: [
                  EstadoVacio(
                    icono: widget.emergencia ? Icons.health_and_safety : Icons.diversity_3,
                    texto: widget.emergencia
                        ? 'No hay pedidos con ese filtro. Si alguien necesita ayuda, publícalo con el botón de abajo.'
                        : 'Aún no hay publicaciones aquí. ¡Sé el primero en pedir u ofrecer un favor!',
                  ),
                ]);
              }
              return ListView.builder(
                padding: const EdgeInsets.only(top: 4, bottom: 96),
                itemCount: lista.length,
                itemBuilder: (_, i) => TarjetaPublicacion(lista[i]),
              );
            },
          ),
        ),
      ),
    ]);
  }
}
