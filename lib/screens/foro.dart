import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/tema.dart';
import '../ui/widgets.dart';
import 'auth_screen.dart';
import 'foro_detalle.dart';
import 'foro_modales.dart';
import 'foro_widgets.dart';

/// Pestaña Foro Vecinal: Espacio comunitario para consultas, oficios y diálogo barrial.
class ForoScreen extends StatefulWidget {
  const ForoScreen({super.key});

  @override
  State<ForoScreen> createState() => _ForoScreenState();
}

class _ForoScreenState extends State<ForoScreen> {
  final TextEditingController _buscarCtrl = TextEditingController();
  String _busqueda = '';
  String _filtroTipo = 'todos';
  String _filtroSector = 'todos';

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  void _abrirNuevaPublicacion() {
    final st = context.read<AppState>();
    if (!st.logueado) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthScreen(
            mensaje: 'Para publicar en el foro necesitas ingresar con tu cuenta de vecino.',
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ModalNuevoTema(),
    );
  }

  Future<void> _toggleApoyo(TemaForo tema) async {
    final st = context.read<AppState>();
    if (!st.logueado) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthScreen(
            mensaje: 'Para apoyar una consulta necesitas ingresar con tu cuenta de vecino.',
          ),
        ),
      );
      return;
    }

    final nuevoEstado = !tema.apoyadoPorUsuario;
    setState(() {
      tema.apoyadoPorUsuario = nuevoEstado;
      tema.apoyos += nuevoEstado ? 1 : -1;
    });

    try {
      await st.repo.toggleApoyoForo(tema.id, nuevoEstado);
    } catch (_) {
      if (mounted) {
        setState(() {
          tema.apoyadoPorUsuario = !nuevoEstado;
          tema.apoyos += !nuevoEstado ? 1 : -1;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();

    const opcionesTipo = [
      ('todos', 'Todos', Icons.grid_view_rounded, Paleta.primario),
      ('servicio', 'Consultas de oficios', Icons.handyman_rounded, Paleta.azulInfo),
      ('dialogo', 'Comunidad', Icons.forum_rounded, Paleta.verde),
      ('recomendacion', 'Recomendaciones', Icons.verified_rounded, Paleta.ambar),
      ('aviso', 'Avisos vecinales', Icons.campaign_rounded, Paleta.violeta),
    ];

    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: Cargador<List<TemaForo>>(
        claves: [st.version],
        cargar: (st) async {
          final filas = await st.repo.temasForo();
          return filas.map((m) => TemaForo.fromMap(m, miUid: st.uid)).toList();
        },
        builder: (context, todosLosTemas) {
          final temasFiltrados = todosLosTemas.where((t) {
            if (_filtroTipo != 'todos') {
              final tipoStr = switch (t.tipo) {
                TipoPublicacionForo.servicio => 'servicio',
                TipoPublicacionForo.dialogo => 'dialogo',
                TipoPublicacionForo.recomendacion => 'recomendacion',
                TipoPublicacionForo.aviso => 'aviso',
              };
              if (tipoStr != _filtroTipo) return false;
            }

            if (_filtroSector != 'todos' && t.sector != _filtroSector) {
              return false;
            }

            if (_busqueda.isNotEmpty) {
              final query = _busqueda.toLowerCase();
              final matchTitulo = t.titulo.toLowerCase().contains(query);
              final matchContenido = t.contenido.toLowerCase().contains(query);
              final matchAutor = t.autorNombre.toLowerCase().contains(query);
              final matchSector = t.sector.toLowerCase().contains(query);
              final matchOficio = (t.categoriaServicio ?? '')
                  .toLowerCase()
                  .contains(query);
              return matchTitulo ||
                  matchContenido ||
                  matchAutor ||
                  matchSector ||
                  matchOficio;
            }
            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              // 1. Banner Comunitario con vida y color
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Paleta.tinta, Paleta.primarioClaro],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Paleta.tinta.withValues(alpha: 0.16),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _abrirNuevaPublicacion,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Paleta.acento.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Paleta.acento.withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Icon(
                                Icons.forum_rounded,
                                color: Paleta.acento,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 13),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Diálogo y Servicios del Barrio',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Consulta por un oficio o comparte una recomendación',
                                    style: TextStyle(
                                      color: Paleta.lineaFuerte,
                                      fontSize: 12,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Paleta.acento,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Paleta.acento.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add, size: 16, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Publicar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Buscador limpio
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Paleta.linea),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x061E293B),
                        blurRadius: 12,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _buscarCtrl,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) =>
                        setState(() => _busqueda = v.trim().toLowerCase()),
                    style: const TextStyle(fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Buscar consultas o servicios...',
                      hintStyle: TextStyle(
                        color: Paleta.grisClaro,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Paleta.gris,
                        size: 21,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Fila de categorías con color activo e iconos
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final (valor, texto, icono, colorActivo)
                        in opcionesTipo)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: Icon(
                            icono,
                            size: 15,
                            color: _filtroTipo == valor
                                ? Colors.white
                                : colorActivo,
                          ),
                          label: Text(texto),
                          labelStyle: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _filtroTipo == valor
                                ? Colors.white
                                : Paleta.tinta,
                          ),
                          selected: _filtroTipo == valor,
                          selectedColor: colorActivo,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: _filtroTipo == valor
                                ? colorActivo
                                : Paleta.linea,
                          ),
                          showCheckmark: false,
                          onSelected: (_) =>
                              setState(() => _filtroTipo = valor),
                        ),
                      ),
                  ],
                ),
              ),

              // 4. Barra de resultados con selector de Sector desplegable
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${temasFiltrados.length} ${temasFiltrados.length == 1 ? 'publicación' : 'publicaciones'}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Paleta.tinta,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Filtrar por sector',
                      initialValue: _filtroSector,
                      onSelected: (sec) => setState(() => _filtroSector = sec),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'todos',
                          child: Text('Todo Chimbote'),
                        ),
                        const PopupMenuDivider(),
                        for (final s in Zona.sectores.keys)
                          PopupMenuItem(value: s, child: Text(s)),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Paleta.linea),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Paleta.gris,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _filtroSector == 'todos'
                                  ? 'Sector: Todos'
                                  : _filtroSector,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Paleta.tinta,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              size: 18,
                              color: Paleta.gris,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 5. Estado de la lista (vacío en base de datos o resultados filtrados)
              if (todosLosTemas.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 48,
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Paleta.primarioSuave,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.forum_outlined,
                            size: 30,
                            color: Paleta.primario,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Aún no hay publicaciones en el foro',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Paleta.tinta,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Sé el primer vecino en consultar por un servicio, pedir una recomendación o iniciar una conversación en el barrio.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Paleta.gris,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Paleta.primario,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _abrirNuevaPublicacion,
                          icon: const Icon(Icons.edit_note, size: 20),
                          label: const Text(
                            'Hacer la primera pregunta',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (temasFiltrados.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Paleta.primarioSuave,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.search_off_outlined,
                            size: 28,
                            color: Paleta.primario,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No se encontraron publicaciones',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Paleta.tinta,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Prueba cambiando el sector o la categoría de búsqueda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Paleta.gris),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...temasFiltrados.map(
                  (t) => TarjetaForo(
                    tema: t,
                    onApoyar: () => _toggleApoyo(t),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetalleTemaForoScreen(
                            tema: t,
                            onToggleApoyo: () => _toggleApoyo(t),
                          ),
                        ),
                      );
                      st.refrescar();
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
