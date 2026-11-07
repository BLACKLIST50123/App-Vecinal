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
import 'publicar.dart';

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
                    child: Text('${lista.length} ${lista.length == 1 ? 'resultado' : 'resultados'}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19)),
                  ),
                ),
                PopupMenuButton<bool>(
                  tooltip: 'Ordenar',
                  initialValue: _porCercania,
                  onSelected: (v) => setState(() => _porCercania = v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: false, child: Text('Más recomendados')),
                    PopupMenuItem(value: true, child: Text('Más cerca de mí')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.swap_vert, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(_porCercania ? 'Más cerca' : 'Más recomendados',
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                    ]),
                  ),
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

          return ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            // 0 ─ Alertas SOS (día a día; en emergencia ya están en el tablero)
            if (!e) const FranjaAlertasSos(maximo: 3),
            // 1 ─ Banner y dos caminos
            BannerDegradado(
              icono: e ? Icons.volunteer_activism : Icons.favorite_border,
              titulo: e ? 'Cada ayuda cuenta' : 'Una pequeña ayuda cambia el día',
              subtitulo: e
                  ? 'Mira quién necesita ayuda y qué hay para compartir.'
                  : 'Entre vecinos, sin dinero de por medio.',
              colores: e ? const [Color(0xFFE53935), Color(0xFFEF5350)] : const [Paleta.acentoOscuro, Paleta.acento],
              colorIcono: Colors.white,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: e ? FilledButton.styleFrom(backgroundColor: Paleta.rojo) : null,
                    onPressed: () => abrirFormulario(context, e ? TipoForm.necesitoAyuda : TipoForm.pidoFavor),
                    icon: const Icon(Icons.front_hand_outlined),
                    label: Text(e ? 'Necesito ayuda' : 'Necesito una mano'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => abrirFormulario(context, e ? TipoForm.ofrezcoRecurso : TipoForm.ofrezcoFavor),
                    icon: const Icon(Icons.volunteer_activism_outlined),
                    label: Text(e ? 'Tengo algo' : 'Quiero dar algo'),
                  ),
                ),
              ]),
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
              TituloDiseno('Colectas del barrio',
                  ceja: 'Responsabilidad social',
                  accion: ('Organizar', () => abrirFormulario(context, TipoForm.colecta))),
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
              e ? 'Pedidos y recursos' : 'Solicitudes de vecinos',
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
                texto: e ? 'Por ahora no hay nada aquí.' : 'Todavía no hay solicitudes. ¿Te falta algo? Toca "Necesito una mano".',
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
                            valor: '${nivel.emoji} $n ${n == 1 ? 'ayuda' : 'ayudas'}',
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
