import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../data/sugerencias.dart';
import '../../models.dart';
import '../../screens/auth_screen.dart';
import '../../screens/confianza.dart';
import '../../screens/detalles.dart';
import '../../screens/publicar.dart';
import '../../services/dictado.dart';
import '../../state/app_state.dart';
import '../../ui/diseno.dart';
import '../../ui/tema.dart';
import '../../ui/widgets.dart';
import '../../util.dart';
import '../sos/sos_alertas.dart';
import 'clasificador.dart';
import 'mapa_apoyo.dart';
import 'tarjeta_apoyo.dart';

/// Solidaridad (día a día). Tres apartados bien separados:
///   1. Tu rango en el barrio (escalera de medallas)
///   2. Colectas del barrio (carrusel horizontal)
///   3. Solidaridad vecinal → [Apoyar] [Pedir ayuda]
class SolidaridadScreen extends StatefulWidget {
  const SolidaridadScreen({super.key, this.irAPerfil, this.iniciarEnPedir = false});

  /// "Ver más" del rango lleva al perfil.
  final VoidCallback? irAPerfil;

  /// Abre directo en "Pedir ayuda" (acceso rápido del Inicio).
  final bool iniciarEnPedir;

  @override
  State<SolidaridadScreen> createState() => _SolidaridadScreenState();
}

class _SolidaridadScreenState extends State<SolidaridadScreen> {
  late bool _pedir = widget.iniciarEnPedir; // false = Apoyar (por defecto), true = Pedir ayuda

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final ayudas = (st.perfil?['ayudas_confirmadas'] as num?)?.toInt() ?? 0;
    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: ListView(padding: const EdgeInsets.only(bottom: 110), children: [
        // Alertas SOS: solo ocupan espacio si hay una activa.
        const FranjaAlertasSos(),

        // ─────────────────────────────── 1. Tu rango en el barrio
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TarjetaRango(ayudas: ayudas, onVerMas: widget.irAPerfil),
        ),

        // ─────────────────────────────── 2. Colectas del barrio
        const _Separador(),
        TituloDiseno('Colectas del barrio', accion: ('Organizar', () => abrirFormulario(context, TipoForm.colecta))),
        Cargador<List<Publicacion>>(
          cargar: (st) => st.repo.publicaciones(emergencia: false),
          builder: (c, todas) {
            final colectas = todas.where((p) => p.esColecta).toList()..sort((a, b) => b.progreso.compareTo(a.progreso));
            if (colectas.isEmpty) {
              return Padding(
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

        // ─────────────────────────────── 3. Solidaridad vecinal
        const _Separador(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
          child: Row(children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Solidaridad vecinal', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19)),
              ),
            ),
            IconButton(
              tooltip: 'Cómo ayudar con seguridad',
              onPressed: () => mostrarConsejos(context),
              icon: Icon(Icons.shield_outlined, color: Paleta.gris),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: _SelectorModo(pedir: _pedir, alCambiar: (v) => setState(() => _pedir = v)),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _pedir ? const _PestanaPedir(key: ValueKey('pedir')) : const _PestanaApoyar(key: ValueKey('apoyar')),
        ),
      ]),
    );
  }
}

/// Línea fina entre apartados para que se distingan bien.
class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) =>
      Padding(padding: EdgeInsets.fromLTRB(20, 22, 20, 0), child: Divider(height: 1, color: Paleta.linea));
}

/// Interruptor tipo pastilla: Apoyar | Pedir ayuda.
class _SelectorModo extends StatelessWidget {
  const _SelectorModo({required this.pedir, required this.alCambiar});
  final bool pedir;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) {
    Widget opcion(bool valor, IconData icono, String texto) {
      final sel = pedir == valor;
      return Expanded(
        child: Semantics(
          selected: sel,
          button: true,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              alCambiar(valor);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 48,
              decoration: BoxDecoration(
                color: sel ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: sel ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))] : null,
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icono, size: 20, color: sel ? Paleta.primario : Paleta.gris),
                const SizedBox(width: 8),
                Text(texto,
                    style: TextStyle(
                        fontSize: 15, fontWeight: sel ? FontWeight.w800 : FontWeight.w600, color: sel ? Paleta.primario : Paleta.gris)),
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Paleta.grisFondo, borderRadius: BorderRadius.circular(999)),
      child: Row(children: [
        opcion(false, Icons.volunteer_activism_rounded, 'Apoyar'),
        opcion(true, Icons.front_hand_rounded, 'Pedir ayuda'),
      ]),
    );
  }
}

// =================================================================== Rango

/// "Tu rango en el barrio": solo la escalera. El rango actual a color y los
/// siguientes en gris, para que se vea hacia dónde puede subir.
class TarjetaRango extends StatelessWidget {
  const TarjetaRango({super.key, required this.ayudas, this.onVerMas});
  final int ayudas;
  final VoidCallback? onVerMas;

  @override
  Widget build(BuildContext context) {
    final actual = Nivel.de(ayudas);
    final i = actual.indice;
    const visibles = 4;
    final inicio = (i).clamp(0, Nivel.todos.length - visibles);
    final escalera = Nivel.todos.sublist(inicio, inicio + visibles);
    final sig = Nivel.siguiente(ayudas);

    return Semantics(
      container: true,
      label: 'Tu rango en el barrio: ${actual.nombre}.'
          '${sig == null ? ' Es el rango más alto.' : ' El siguiente es ${sig.nombre}.'}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 6, 16),
        decoration: BoxDecoration(
          color: Paleta.superficie,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Paleta.linea),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('Tu rango en el barrio', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Paleta.tinta)),
            ),
            TextButton(
              onPressed: onVerMas,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Ver más'),
                Icon(Icons.chevron_right_rounded, size: 20),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ExcludeSemantics(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var k = 0; k < escalera.length; k++) ...[
                  if (k > 0)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 25),
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: escalera[k].indice <= i ? escalera[k].color : Paleta.linea,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  _Peldano(escalera[k], alcanzado: escalera[k].indice <= i, actual: escalera[k].indice == i),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Peldano extends StatelessWidget {
  const _Peldano(this.nivel, {required this.alcanzado, required this.actual});
  final Nivel nivel;
  final bool alcanzado, actual;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 66,
        child: Column(children: [
          SizedBox(
            height: 54,
            child: Center(child: MedallaNivel(nivel, tamano: actual ? 50 : 40, bloqueada: !alcanzado, actual: actual)),
          ),
          const SizedBox(height: 6),
          Text(
            nivel.corto,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 13,
              height: 1.15,
              fontWeight: actual ? FontWeight.w800 : FontWeight.w600,
              color: actual ? nivel.color : (alcanzado ? Paleta.tinta : Paleta.grisClaro),
            ),
          ),
        ]),
      );
}

// =================================================================== Apoyar

class _PestanaApoyar extends StatefulWidget {
  const _PestanaApoyar({super.key});

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
          final abiertas = todas
              .where((p) => p.esPedido && !p.esColecta && p.estado != 'resuelta' && !(p.autorId != null && p.autorId == st.uid))
              .toList();
          final conteo = <String, int>{};
          for (final p in abiertas) {
            final c = categoriaPeticion(p.categoria);
            conteo[c] = (conteo[c] ?? 0) + 1;
          }
          final lista = abiertas.where((p) => _categoria == null || categoriaPeticion(p.categoria) == _categoria).toList()
            // Primero las urgentes, y dentro de cada grupo de la más cercana a la más lejana.
            ..sort((a, b) {
              if (a.esUrgente != b.esUrgente) return a.esUrgente ? -1 : 1;
              return d(a).compareTo(d(b));
            });

          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _DesplegableCategoria(
                valor: _categoria,
                conteo: conteo,
                total: abiertas.length,
                alCambiar: (v) => setState(() => _categoria = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      lista.isEmpty
                          ? 'Nadie está pidiendo ayuda'
                          : '${lista.length} ${lista.length == 1 ? 'petición cerca de ti' : 'peticiones cerca de ti'}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Paleta.tinta),
                    ),
                    if (lista.isNotEmpty)
                      Text('Urgentes primero, luego las más cercanas',
                          style: TextStyle(fontSize: 13, color: Paleta.gris)),
                  ]),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: lista.isEmpty
                      ? null
                      : () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => MapaApoyoScreen(
                              peticiones: [...lista]..sort((a, b) => d(a).compareTo(d(b))),
                              categoria: _categoria,
                            ),
                          )),
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 42),
                  ),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Ver mapa'),
                ),
              ]),
            ),
            if (lista.isEmpty)
              const EstadoVacio(icono: Icons.diversity_3, texto: 'En esta categoría no hay peticiones. ¡Buena señal!')
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

/// Desplegable "Elige categoría" con ícono y cuántas peticiones hay en cada una.
class _DesplegableCategoria extends StatelessWidget {
  const _DesplegableCategoria({required this.valor, required this.conteo, required this.total, required this.alCambiar});
  final String? valor;
  final Map<String, int> conteo;
  final int total;
  final ValueChanged<String?> alCambiar;

  @override
  Widget build(BuildContext context) {
    final opciones = <(String?, String, IconData, int)>[
      (null, 'Todas las categorías', Icons.apps_rounded, total),
      for (final c in categoriasPeticion) (c.id, c.nombre, c.icono, conteo[c.id] ?? 0),
    ];

    Widget fila((String?, String, IconData, int) o, {bool compacta = false}) {
      final colores = coloresPeticion(o.$1);
      return Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: colores.$2, borderRadius: BorderRadius.circular(10)),
          child: Icon(o.$3, size: 19, color: colores.$1),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(o.$2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: compacta ? FontWeight.w700 : FontWeight.w500, color: Paleta.tinta)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: o.$4 == 0 ? Paleta.grisFondo : Paleta.primarioSuave,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text('${o.$4}',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: o.$4 == 0 ? Paleta.grisClaro : Paleta.primario)),
        ),
      ]);
    }

    return DropdownButtonFormField<String?>(
      initialValue: valor,
      isExpanded: true,
      borderRadius: BorderRadius.circular(16),
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: InputDecoration(
        labelText: 'Elige categoría',
        filled: true,
        fillColor: Paleta.superficie,
        contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Paleta.linea)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Paleta.linea)),
      ),
      selectedItemBuilder: (c) => [for (final o in opciones) fila(o, compacta: true)],
      items: [for (final o in opciones) DropdownMenuItem<String?>(value: o.$1, child: fila(o))],
      onChanged: alCambiar,
    );
  }
}

// ============================================================== Pedir ayuda

class _PestanaPedir extends StatefulWidget {
  const _PestanaPedir({super.key});

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
  bool _escuchando = false;

  @override
  void initState() {
    super.initState();
    _texto.addListener(_alEscribir);
  }

  @override
  void dispose() {
    Dictado.soltar();
    _texto.removeListener(_alEscribir);
    _texto.dispose();
    super.dispose();
  }

  /// Mientras escribe (o dicta): detecta la categoría y la urgencia por
  /// palabras clave, salvo que la persona ya las haya elegido a mano.
  void _alEscribir() {
    final v = _texto.text;
    final c = Clasificador.categoria(v);
    setState(() {
      if (!_categoriaManual) {
        _categoria = c.categoria;
        _detectada = c.detectada;
      }
      if (!_urgenciaManual) _urgente = Clasificador.esUrgente(v);
    });
  }

  void _usarIdea(FraseRapida f) {
    HapticFeedback.selectionClick();
    if (_escuchando) Dictado.detener();
    _categoriaManual = false;
    _texto.value = TextEditingValue(text: f.texto, selection: TextSelection.collapsed(offset: f.texto.length));
  }

  Future<void> _dictar() async {
    if (_escuchando) {
      await Dictado.detener();
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    final ok = await Dictado.escuchar(
      alTexto: (texto, _) {
        if (!mounted || texto.isEmpty) return;
        final limpio = texto[0].toUpperCase() + texto.substring(1);
        _categoriaManual = false;
        _texto.value = TextEditingValue(text: limpio, selection: TextSelection.collapsed(offset: limpio.length));
      },
      alCambiar: (v) {
        if (mounted && v != _escuchando) setState(() => _escuchando = v);
      },
    );
    if (!ok && mounted) avisar('Este celular no permite dictar aquí. Toca una idea o usa el micrófono del teclado.');
  }

  Future<void> _cambiarCategoria() async {
    final elegida = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('¿De qué tipo es tu petición?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          for (final cat in categoriasPeticion)
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: coloresPeticion(cat.id).$2, borderRadius: BorderRadius.circular(10)),
                child: Icon(cat.icono, size: 20, color: coloresPeticion(cat.id).$1),
              ),
              title: Text(cat.nombre),
              trailing: cat.id == _categoria ? Icon(Icons.check_rounded, color: Paleta.primario) : null,
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
    final problema = texto.isEmpty
        ? 'Escribe en pocas palabras qué necesitas.'
        : validarTitulo(texto.length > Limites.titulo ? texto.substring(0, Limites.titulo) : texto) ??
            validarTexto(texto, min: 5, max: 300);
    if (problema != null) {
      avisar(problema);
      return;
    }
    if (!st.logueado) {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => const AuthScreen(mensaje: 'Para pedir ayuda necesitas una cuenta de vecino. Es gratis y toma 1 minuto.'),
      ));
      return;
    }
    if (_escuchando) await Dictado.detener();
    setState(() => _enviando = true);
    final aprox = aproximar(st.referencia);
    final datos = <String, dynamic>{
      'id': nuevoId(),
      'tipo': 'pido',
      'categoria': _categoria,
      'titulo': texto.length > Limites.titulo ? '${texto.substring(0, Limites.titulo - 3)}...' : texto,
      'descripcion': texto.length > Limites.titulo ? texto : null,
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
      _texto.removeListener(_alEscribir);
      _texto.clear();
      _texto.addListener(_alEscribir);
      setState(() {
        _categoria = 'otros';
        _detectada = false;
        _categoriaManual = false;
        _urgente = false;
        _urgenciaManual = false;
      });
      FocusScope.of(context).unfocus();
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
    final colores = coloresPeticion(_categoria);
    final hayTexto = _texto.text.trim().length >= 3;
    final ideas = (frasesRapidas['pidoFavor'] ?? const <FraseRapida>[]).take(4);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(color: Paleta.superficie, borderRadius: BorderRadius.circular(20), border: Border.all(color: Paleta.linea)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Paso 1
          const _Paso(1, '¿Qué necesitas?', 'Escríbelo o díctalo como se lo dirías a un vecino.'),
          const SizedBox(height: 10),
          TextField(
            controller: _texto,
            minLines: 3,
            maxLines: 5,
            maxLength: 300,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 16, height: 1.35),
            decoration: InputDecoration(
              hintText: 'Ej: Necesito que me presten una escalera hoy',
              filled: true,
              fillColor: Paleta.crema,
              contentPadding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Paleta.linea)),
              enabledBorder:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Paleta.linea)),
              focusedBorder:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Paleta.primario, width: 1.6)),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Align(
                  alignment: Alignment.topRight,
                  widthFactor: 1,
                  heightFactor: 1,
                  child: IconButton.filledTonal(
                    tooltip: _escuchando ? 'Dejar de dictar' : 'Dictar con la voz',
                    onPressed: _dictar,
                    style: IconButton.styleFrom(
                      backgroundColor: _escuchando ? Paleta.rojo : Paleta.primarioSuave,
                      foregroundColor: _escuchando ? Colors.white : Paleta.primario,
                    ),
                    icon: Icon(_escuchando ? Icons.stop_rounded : Icons.mic_rounded),
                  ),
                ),
              ),
            ),
          ),
          if (!hayTexto) ...[
            Text('Ideas rápidas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Paleta.gris)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final f in ideas)
                ActionChip(
                  avatar: Icon(f.icono, size: 18, color: Paleta.primario),
                  label: Text(f.texto),
                  backgroundColor: Paleta.superficie,
                  side: BorderSide(color: Paleta.linea),
                  shape: const StadiumBorder(),
                  onPressed: () => _usarIdea(f),
                ),
            ]),
          ] else
            // Lo que entendimos + Cambiar
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
              decoration: BoxDecoration(color: colores.$2, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: Paleta.superficie, borderRadius: BorderRadius.circular(10)),
                  child: Icon(cat.icono, size: 20, color: colores.$1),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_detectada ? 'Lo entendimos como' : 'No identificamos la categoría',
                        style: TextStyle(fontSize: 12, color: Paleta.gris, fontWeight: FontWeight.w600)),
                    Text(_detectada ? cat.nombre : 'Otro',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: colores.$1)),
                  ]),
                ),
                TextButton(onPressed: _cambiarCategoria, child: const Text('Cambiar')),
              ]),
            ),

          // ── Paso 2
          const SizedBox(height: 20),
          const _Paso(2, '¿Qué tan pronto?', null),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _OpcionUrgencia(
                icono: Icons.schedule_rounded,
                titulo: 'Puede esperar',
                detalle: 'En los próximos días',
                elegida: !_urgente,
                color: Paleta.primario,
                onTap: () => setState(() {
                  _urgente = false;
                  _urgenciaManual = true;
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _OpcionUrgencia(
                icono: Icons.bolt_rounded,
                titulo: 'Hoy mismo',
                detalle: 'Se muestra primero',
                elegida: _urgente,
                color: Paleta.rojo,
                onTap: () => setState(() {
                  _urgente = true;
                  _urgenciaManual = true;
                }),
              ),
            ),
          ]),
          if (_urgente && !_urgenciaManual)
            Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Lo marcamos por lo que escribiste. Puedes cambiarlo.',
                  style: TextStyle(fontSize: 12, color: Paleta.gris)),
            ),

          // ── Enviar
          const SizedBox(height: 20),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: _enviando ? null : _pedir,
              icon: _enviando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: const Text('Pedir ayuda', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 10),
          const _Nota(Icons.place_outlined, 'Solo mostramos tu zona aproximada (±200 m).'),
          const _Nota(Icons.cloud_off_outlined, '¿Sin señal? Se enviará cuando vuelva.'),
        ]),
      ),
      const _Separador(),
      const TituloDiseno('Mis peticiones'),
      const _MisPeticiones(),
    ]);
  }
}

/// Encabezado numerado de cada paso del formulario.
class _Paso extends StatelessWidget {
  const _Paso(this.numero, this.titulo, this.ayuda);
  final int numero;
  final String titulo;
  final String? ayuda;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(top: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Paleta.primario, shape: BoxShape.circle),
            child: Text('$numero', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Paleta.tinta)),
              if (ayuda != null) Text(ayuda!, style: TextStyle(fontSize: 13, color: Paleta.gris)),
            ]),
          ),
        ]),
      );
}

class _OpcionUrgencia extends StatelessWidget {
  const _OpcionUrgencia({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.elegida,
    required this.color,
    required this.onTap,
  });
  final IconData icono;
  final String titulo, detalle;
  final bool elegida;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: elegida,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: elegida ? color.withValues(alpha: 0.08) : Paleta.superficie,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: elegida ? color : Paleta.linea, width: elegida ? 2 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icono, size: 20, color: elegida ? color : Paleta.gris),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(titulo,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: elegida ? color : Paleta.tinta)),
                ),
              ]),
              const SizedBox(height: 2),
              Text(detalle, style: TextStyle(fontSize: 12, color: Paleta.gris)),
            ]),
          ),
        ),
      );
}

class _Nota extends StatelessWidget {
  const _Nota(this.icono, this.texto);
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icono, size: 14, color: Paleta.gris),
          const SizedBox(width: 4),
          Flexible(child: Text(texto, style: TextStyle(fontSize: 12, color: Paleta.gris))),
        ]),
      );
}

/// Mis peticiones: de la más reciente a la más antigua, con su estado.
class _MisPeticiones extends StatelessWidget {
  const _MisPeticiones();

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    if (!st.logueado) {
      return Padding(
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
          return Padding(
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
                  _IconoEstado(p),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.titulo, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text('${fechaHora(p.creado)} · ${buscarCategoria(p.categoria).nombre}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Paleta.gris, fontSize: 13)),
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

/// Estado de una petición: (texto, ícono, color).
(String, IconData, Color) _estado(Publicacion p) => p.estado == 'resuelta'
    ? ('Atendida', Icons.check_circle_rounded, Paleta.verde)
    : p.ayudantes > 0
        ? ('${p.ayudantes} ${p.ayudantes == 1 ? 'te apoya' : 'te apoyan'}', Icons.groups_rounded, Paleta.azulInfo)
        : p.pendiente
            ? ('Por enviar', Icons.cloud_off_rounded, Paleta.gris)
            : ('Esperando', Icons.hourglass_top_rounded, Paleta.ambar);

class _IconoEstado extends StatelessWidget {
  const _IconoEstado(this.p);
  final Publicacion p;

  @override
  Widget build(BuildContext context) {
    final (_, icono, color) = _estado(p);
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: Icon(icono, size: 20, color: color),
    );
  }
}

class _EstadoPeticion extends StatelessWidget {
  const _EstadoPeticion(this.p);
  final Publicacion p;

  @override
  Widget build(BuildContext context) {
    final (texto, _, color) = _estado(p);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
      child: Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}
