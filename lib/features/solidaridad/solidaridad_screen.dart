import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models.dart';
import '../../screens/auth_screen.dart';
import '../../screens/confianza.dart';
import '../../screens/detalles.dart';
import '../../screens/publicar.dart';
import '../../state/app_state.dart';
import '../../ui/diseno.dart';
import '../../ui/tema.dart';
import '../../ui/widgets.dart';
import '../../util.dart';
import '../sos/sos_alertas.dart';
import 'clasificador.dart';
import 'mapa_apoyo.dart';
import 'tarjeta_apoyo.dart';

/// Solidaridad (día a día). Estructura vertical:
///   1. Colectas del barrio (carrusel horizontal)
///   2. Solidaridad vecinal → [Apoyar] [Pedir ayuda]
/// Las dos pestañas se complementan: lo que se pide en una se apoya en la otra.
class SolidaridadScreen extends StatefulWidget {
  const SolidaridadScreen({super.key});

  @override
  State<SolidaridadScreen> createState() => _SolidaridadScreenState();
}

class _SolidaridadScreenState extends State<SolidaridadScreen> {
  bool _pedir = false; // false = Apoyar (por defecto), true = Pedir ayuda

  @override
  Widget build(BuildContext context) {
    final st = context.read<AppState>();
    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
        // Alertas SOS: solo ocupan espacio si hay una activa.
        const FranjaAlertasSos(maximo: 2),

        // ─────────────────────────────── 1. Colectas del barrio
        TituloDiseno('Colectas del barrio',
            ceja: 'Responsabilidad social', accion: ('Organizar', () => abrirFormulario(context, TipoForm.colecta))),
        Cargador<List<Publicacion>>(
          cargar: (st) => st.repo.publicaciones(emergencia: false),
          builder: (c, todas) {
            final colectas = todas.where((p) => p.esColecta).toList()..sort((a, b) => b.progreso.compareTo(a.progreso));
            if (colectas.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text('No hay colectas activas. ¿Tu barrio necesita una? Toca "Organizar".',
                    style: TextStyle(color: Paleta.gris)),
              );
            }
            return SizedBox(
              height: 206,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [for (final p in colectas) TarjetaColecta(p)],
              ),
            );
          },
        ),

        // ─────────────────────────────── 2. Solidaridad vecinal
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 8, 4),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Semantics(
                  header: true,
                  child: Text('Solidaridad vecinal', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19)),
                ),
                const Text('Ayuda entre vecinos, sin dinero.', style: TextStyle(color: Paleta.gris, fontSize: 14)),
              ]),
            ),
            IconButton(
              tooltip: 'Cómo ayudar con seguridad',
              onPressed: () => mostrarConsejos(context),
              icon: const Icon(Icons.shield_outlined),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(minimumSize: const Size(0, 52)),
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.volunteer_activism_outlined), label: Text('Apoyar')),
              ButtonSegment(value: true, icon: Icon(Icons.front_hand_outlined), label: Text('Pedir ayuda')),
            ],
            selected: {_pedir},
            onSelectionChanged: (s) => setState(() => _pedir = s.first),
          ),
        ),
        if (_pedir) const _PestanaPedir() else const _PestanaApoyar(),
      ]),
    );
  }
}

// =================================================================== Apoyar

class _PestanaApoyar extends StatefulWidget {
  const _PestanaApoyar();

  @override
  State<_PestanaApoyar> createState() => _PestanaApoyarState();
}

class _PestanaApoyarState extends State<_PestanaApoyar> {
  String? _categoria; // null = todas

  @override
  Widget build(BuildContext context) => Cargador<List<Publicacion>>(
        cargar: (st) => st.repo.publicaciones(emergencia: false),
        builder: (context, todas) {
          final st = context.read<AppState>();
          final ref = st.referencia;
          double d(Publicacion p) => p.punto == null ? 9999 : distanciaKm(ref, p.punto!);
          // Peticiones abiertas de otros vecinos (sin colectas ni ofrecimientos).
          final lista = todas
              .where((p) =>
                  p.esPedido &&
                  !p.esColecta &&
                  p.estado != 'resuelta' &&
                  !(p.autorId != null && p.autorId == st.uid) &&
                  (_categoria == null || categoriaPeticion(p.categoria) == _categoria))
              .toList()
            // Primero las urgentes, y dentro de cada grupo de la más cercana a la más lejana.
            ..sort((a, b) {
              if (a.esUrgente != b.esUrgente) return a.esUrgente ? -1 : 1;
              return d(a).compareTo(d(b));
            });

          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: DropdownButtonFormField<String?>(
                initialValue: _categoria,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Elige categoría', prefixIcon: Icon(Icons.filter_list)),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                  for (final c in categoriasPeticion)
                    DropdownMenuItem<String?>(
                      value: c.id,
                      child: Row(children: [Icon(c.icono, size: 20), const SizedBox(width: 10), Flexible(child: Text(c.nombre))]),
                    ),
                ],
                onChanged: (v) => setState(() => _categoria = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
              child: Row(children: [
                Expanded(
                  child: Text(
                    '${lista.length} ${lista.length == 1 ? 'petición' : 'peticiones'} · más cercanas primero',
                    style: const TextStyle(color: Paleta.gris, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: lista.isEmpty
                      ? null
                      : () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => MapaApoyoScreen(
                              peticiones: [...lista]..sort((a, b) => d(a).compareTo(d(b))),
                              categoria: _categoria,
                            ),
                          )),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Ver mapa'),
                ),
              ]),
            ),
            if (lista.isEmpty)
              const EstadoVacio(icono: Icons.diversity_3, texto: 'Nadie está pidiendo ayuda en esta categoría. ¡Buena señal!')
            else
              // Carrusel horizontal con tarjetas de igual altura.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    for (final p in lista.take(30)) TarjetaApoyo(p),
                  ]),
                ),
              ),
          ]);
        },
      );
}

// ============================================================== Pedir ayuda

class _PestanaPedir extends StatefulWidget {
  const _PestanaPedir();

  @override
  State<_PestanaPedir> createState() => _PestanaPedirState();
}

class _PestanaPedirState extends State<_PestanaPedir> {
  final _texto = TextEditingController();
  String _categoria = 'otros';
  bool _detectada = false;
  bool _categoriaManual = false;
  bool _urgente = false;
  bool _urgenciaManual = false;
  bool _enviando = false;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  /// Mientras escribe: detecta la categoría y la urgencia por palabras clave
  /// (salvo que la persona ya las haya elegido a mano).
  void _alEscribir(String v) {
    final c = Clasificador.categoria(v);
    setState(() {
      if (!_categoriaManual) {
        _categoria = c.categoria;
        _detectada = c.detectada;
      }
      if (!_urgenciaManual) _urgente = Clasificador.esUrgente(v);
    });
  }

  Future<void> _cambiarCategoria() async {
    final elegida = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('¿De qué tipo es tu petición?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          for (final cat in categoriasPeticion)
            ListTile(
              leading: Icon(cat.icono),
              title: Text(cat.nombre),
              trailing: cat.id == _categoria ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(c, cat.id),
            ),
        ]),
      ),
    );
    if (elegida != null) {
      setState(() {
        _categoria = elegida;
        _detectada = true;
        _categoriaManual = true;
      });
    }
  }

  Future<void> _pedir() async {
    final st = context.read<AppState>();
    final texto = _texto.text.trim();
    if (texto.length < 3) {
      avisar('Escribe en pocas palabras qué necesitas.');
      return;
    }
    if (!st.logueado) {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => const AuthScreen(mensaje: 'Para pedir ayuda necesitas una cuenta de vecino. Es gratis y toma 1 minuto.'),
      ));
      return;
    }
    setState(() => _enviando = true);
    final aprox = aproximar(st.referencia);
    final datos = <String, dynamic>{
      'id': nuevoId(),
      'tipo': 'pido',
      'categoria': _categoria,
      'titulo': texto.length > 140 ? '${texto.substring(0, 137)}...' : texto,
      'descripcion': texto.length > 140 ? texto : null,
      'contacto_nombre': st.nombre,
      'contacto_telefono': st.perfil?['telefono'],
      'prioridad': _urgente ? 'alta' : 'normal',
      'es_emergencia': false,
      'lat': aprox.lat,
      'lng': aprox.lng,
      'sector': st.sector,
      'autor_nombre': st.nombre,
      'creado_offline_en': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      final enviado = await st.publicar('publicaciones', datos);
      if (!mounted) return;
      _texto.clear();
      setState(() {
        _categoria = 'otros';
        _detectada = false;
        _categoriaManual = false;
        _urgente = false;
        _urgenciaManual = false;
      });
      avisar(enviado
          ? '¡Listo! Tus vecinos ya pueden apoyarte.'
          : 'Quedó guardada sin internet. Se publicará cuando vuelva la señal.');
    } catch (e) {
      avisar(traducirError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = buscarCategoria(_categoria);
    final primario = Theme.of(context).colorScheme.primary;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              controller: _texto,
              onChanged: _alEscribir,
              minLines: 2,
              maxLines: 4,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                labelText: '¿Qué necesitas?',
                hintText: 'Ej: Necesito que me presten una escalera hoy',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 104,
            height: 84,
            child: FilledButton(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
              onPressed: _enviando ? null : _pedir,
              child: _enviando
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3))
                  : const Text('Pedir\nayuda', textAlign: TextAlign.center),
            ),
          ),
        ]),
      ),
      // Categoría detectada + Cambiar
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
        child: Row(children: [
          Icon(cat.icono, size: 20, color: _detectada ? primario : Paleta.gris),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _detectada || _categoria != 'otros' ? cat.nombre : 'Otro · categoría no identificada',
              style: TextStyle(fontWeight: FontWeight.w700, color: _detectada ? primario : Paleta.gris),
            ),
          ),
          TextButton(onPressed: _cambiarCategoria, child: const Text('Cambiar')),
        ]),
      ),
      // Urgencia (2 niveles)
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Row(children: [
          const Text('¿Es urgente?', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Expanded(
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Puede esperar')),
                ButtonSegment(value: true, icon: Icon(Icons.priority_high), label: Text('Urgente')),
              ],
              selected: {_urgente},
              onSelectionChanged: (s) => setState(() {
                _urgente = s.first;
                _urgenciaManual = true;
              }),
            ),
          ),
        ]),
      ),

      const TituloDiseno('Mis peticiones'),
      const _MisPeticiones(),
    ]);
  }
}

/// Mis peticiones: de la más reciente a la más antigua, con su estado.
class _MisPeticiones extends StatelessWidget {
  const _MisPeticiones();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    if (!st.logueado) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Text('Cuando pidas ayuda, aquí verás tus peticiones y quién te apoya.', style: TextStyle(color: Paleta.gris)),
      );
    }
    return Cargador<(List<Publicacion>, List<Servicio>)>(
      cargar: (st) => st.repo.misPublicaciones(),
      builder: (context, datos) {
        final mias = datos.$1.where((p) => p.esPedido && !p.esColecta && !p.esEmergencia).toList()
          ..sort((a, b) => b.creado.compareTo(a.creado));
        if (mias.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Todavía no has pedido ayuda.', style: TextStyle(color: Paleta.gris)),
          );
        }
        return ListaAjustes(filas: [
          for (final p in mias)
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicacionDetalle(publicacion: p))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Icon(buscarCategoria(p.categoria).icono, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.titulo, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(fechaHora(p.creado), style: const TextStyle(color: Paleta.gris, fontSize: 13)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  _EstadoPeticion(p),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

class _EstadoPeticion extends StatelessWidget {
  const _EstadoPeticion(this.p);
  final Publicacion p;

  @override
  Widget build(BuildContext context) {
    final (texto, color) = p.estado == 'resuelta'
        ? ('✅ Atendida', const Color(0xFF2E7D32))
        : p.ayudantes > 0
            ? ('🔵 ${p.ayudantes} ${p.ayudantes == 1 ? 'te apoya' : 'te apoyan'}', const Color(0xFF1565C0))
            : p.pendiente
                ? ('⏳ Por enviar', Paleta.gris)
                : ('🟠 Esperando', const Color(0xFFEF6C00));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}
