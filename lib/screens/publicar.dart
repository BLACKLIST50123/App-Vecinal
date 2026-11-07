import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../services/ubicacion.dart';
import '../state/app_state.dart';
import '../util.dart';
import 'auth_screen.dart';
import 'confianza.dart';
import 'detalles.dart';
import 'qr_screens.dart';

/// Publicar en máximo 3 toques:
///   1) botón "Publicar"  2) elegir qué publicar  3) "Publicar ahora".
/// La categoría, la ubicación y el contacto ya vienen completados.
enum TipoForm {
  pidoFavor('Pido un favor', 'Herramientas, ayuda, movilidad... sin dinero', Icons.front_hand),
  ofrezcoFavor('Ofrezco un favor', 'Presto, regalo o enseño algo', Icons.volunteer_activism),
  servicio('Ofrezco un servicio o producto', 'Gasfitería, clases, pan, bodega, artesanía...', Icons.storefront),
  necesitoAyuda('Necesito ayuda', 'Para mí o mi familia. Sin cuenta y sin internet', Icons.sos),
  reportarVulnerable('Reportar vecino vulnerable', 'Adulto mayor, persona enferma o con discapacidad', Icons.elderly),
  ofrezcoRecurso('Ofrezco un recurso', 'Agua, comida, albergue, medicinas...', Icons.inventory_2),
  grupoApoyo('Publicar grupo de apoyo', 'Solo organizaciones verificadas', Icons.health_and_safety);

  const TipoForm(this.titulo, this.subtitulo, this.icono);
  final String titulo, subtitulo;
  final IconData icono;

  bool get esServicio => this == servicio || this == grupoApoyo;
  bool get esEmergencia => this == necesitoAyuda || this == reportarVulnerable || this == ofrezcoRecurso || this == grupoApoyo;
  bool get permiteSinCuenta => this == necesitoAyuda || this == reportarVulnerable;
  String get tipoPub => (this == ofrezcoFavor || this == ofrezcoRecurso) ? 'ofrezco' : 'pido';

  List<Categoria> get categorias => switch (this) {
        pidoFavor || ofrezcoFavor => categoriasFavor,
        servicio => categoriasServicio,
        grupoApoyo => categoriasApoyo,
        necesitoAyuda => categoriasEmergencia.where((c) => c.id != 'recurso' && c.id != 'vulnerable').toList(),
        reportarVulnerable => categoriasEmergencia.where((c) => c.id == 'vulnerable').toList(),
        ofrezcoRecurso => categoriasEmergencia.where((c) => c.id != 'vulnerable' && c.id != 'rescate').toList(),
      };

  String get pista => switch (this) {
        pidoFavor => 'Ej: Necesito una escalera por 2 horas',
        ofrezcoFavor => 'Ej: Presto mi taladro',
        servicio => 'Ej: Gasfitero a domicilio · Pan de yema recién horneado',
        grupoApoyo => 'Ej: Brigada de primeros auxilios',
        necesitoAyuda => 'Ej: Mi casa se inundó, necesitamos agua',
        reportarVulnerable => 'Ej: Señora mayor sola, sin agua, en la Mz. B',
        ofrezcoRecurso => 'Ej: Tengo 20 bidones de agua',
      };

  String get etiquetaTitulo => switch (this) {
        servicio || grupoApoyo => '¿Qué ofreces?',
        ofrezcoFavor || ofrezcoRecurso => '¿Qué ofreces?',
        reportarVulnerable => '¿Quién necesita ayuda y qué necesita?',
        _ => '¿Qué necesitas?',
      };
}

Future<void> abrirMenuPublicar(BuildContext context) {
  final st = context.read<AppState>();
  final opciones = st.modoEmergencia
      ? [
          TipoForm.necesitoAyuda,
          TipoForm.reportarVulnerable,
          TipoForm.ofrezcoRecurso,
          if (st.esOrganizacion || st.esModerador) TipoForm.grupoApoyo,
          TipoForm.pidoFavor,
          TipoForm.ofrezcoFavor,
        ]
      : [TipoForm.pidoFavor, TipoForm.ofrezcoFavor, TipoForm.servicio];
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(
            header: true,
            child: Text('¿Qué quieres publicar?', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          for (final o in opciones)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: o == TipoForm.necesitoAyuda
                    ? const Color(0xFFB71C1C)
                    : Theme.of(c).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  minVerticalPadding: 14,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: Icon(o.icono, size: 36, color: o == TipoForm.necesitoAyuda ? Colors.white : null),
                  title: Text(o.titulo,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17,
                          color: o == TipoForm.necesitoAyuda ? Colors.white : null)),
                  subtitle: Text(o.subtitulo, style: TextStyle(color: o == TipoForm.necesitoAyuda ? Colors.white : null)),
                  onTap: () {
                    Navigator.pop(c);
                    abrirFormulario(context, o);
                  },
                ),
              ),
            ),
        ]),
      ),
    ),
  );
}

void abrirFormulario(BuildContext context, TipoForm t) {
  final st = context.read<AppState>();
  if (!st.logueado && !(t.permiteSinCuenta && st.modoEmergencia)) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const AuthScreen(mensaje: 'Para publicar necesitas una cuenta de vecino. Es gratis y toma 1 minuto.'),
    ));
    return;
  }
  Navigator.push(context, MaterialPageRoute(builder: (_) => FormularioPublicar(tipo: t)));
}

class FormularioPublicar extends StatefulWidget {
  const FormularioPublicar({super.key, required this.tipo});
  final TipoForm tipo;

  @override
  State<FormularioPublicar> createState() => _FormularioPublicarState();
}

class _FormularioPublicarState extends State<FormularioPublicar> {
  final _titulo = TextEditingController();
  final _detalle = TextEditingController();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _precio = TextEditingController();
  final _horario = TextEditingController();
  late String _categoria;
  String? _sector;
  Punto? _gps;
  bool _buscandoGps = true;
  int _personas = 1;
  String _prioridad = 'alta';
  bool _enviando = false;
  String? _error;

  TipoForm get t => widget.tipo;

  @override
  void initState() {
    super.initState();
    final st = context.read<AppState>();
    _categoria = t.categorias.first.id;
    _sector = st.sector;
    if (st.logueado) _nombre.text = st.nombre;
    final tel = st.perfil?['telefono'] as String?;
    if (tel != null) _telefono.text = tel;
    if (t == TipoForm.reportarVulnerable) _prioridad = 'critica';
    _gps = st.ubicacion;
    _buscarGps();
  }

  Future<void> _buscarGps() async {
    setState(() => _buscandoGps = true);
    final p = await Ubicacion.gps();
    if (!mounted) return;
    setState(() {
      if (p != null) _gps = p;
      _buscandoGps = false;
    });
  }

  @override
  void dispose() {
    for (final c in [_titulo, _detalle, _nombre, _telefono, _precio, _horario]) {
      c.dispose();
    }
    super.dispose();
  }

  Punto get _punto => _gps ?? Zona.sectores[_sector] ?? Zona.centro;

  Future<void> _elegirSector() async {
    final elegido = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          ListTile(
            leading: const Icon(Icons.my_location),
            title: const Text('Usar mi ubicación GPS'),
            onTap: () => Navigator.pop(c, '__gps__'),
          ),
          for (final s in Zona.sectores.keys)
            ListTile(leading: const Icon(Icons.place), title: Text(s), onTap: () => Navigator.pop(c, s)),
        ]),
      ),
    );
    if (elegido == null) return;
    if (elegido == '__gps__') {
      await _buscarGps();
    } else {
      setState(() {
        _sector = elegido;
        _gps = null;
      });
    }
  }

  Future<void> _publicar() async {
    final st = context.read<AppState>();
    final titulo = _titulo.text.trim();
    if (titulo.length < 3) {
      setState(() => _error = 'Escribe en pocas palabras ${t.tipoPub == 'pido' ? 'qué necesitas' : 'qué ofreces'}.');
      return;
    }
    if (!st.logueado && _nombre.text.trim().isEmpty) {
      setState(() => _error = 'Escribe tu nombre para que puedan ubicarte.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    final p = _punto;
    final id = nuevoId();
    final detalle = _detalle.text.trim().isEmpty ? null : _detalle.text.trim();
    final tel = _telefono.text.trim().isEmpty ? null : _telefono.text.trim();
    final String tabla;
    final Map<String, dynamic> datos;
    if (t.esServicio) {
      tabla = 'servicios';
      datos = Servicio(
        id: id,
        categoria: _categoria,
        titulo: titulo,
        descripcion: detalle,
        precioRef: _precio.text.trim().isEmpty ? null : _precio.text.trim(),
        telefono: tel,
        horario: _horario.text.trim().isEmpty ? null : _horario.text.trim(),
        sector: _sector,
        lat: p.lat,
        lng: p.lng,
        esEmergencia: t == TipoForm.grupoApoyo,
      ).toInsert();
    } else {
      tabla = 'publicaciones';
      final aprox = aproximar(p);
      datos = {
        'id': id,
        'tipo': t.tipoPub,
        'categoria': _categoria,
        'titulo': titulo,
        'descripcion': detalle,
        'contacto_nombre': _nombre.text.trim().isEmpty ? null : _nombre.text.trim(),
        'contacto_telefono': tel,
        'personas': t.esEmergencia && t.tipoPub == 'pido' ? _personas : null,
        'prioridad': t.esEmergencia && t.tipoPub == 'pido' ? _prioridad : 'normal',
        'es_emergencia': t.esEmergencia,
        'lat': aprox.lat,
        'lng': aprox.lng,
        'sector': _sector,
        'autor_nombre': _nombre.text.trim().isEmpty ? st.nombre : _nombre.text.trim(),
        'creado_offline_en': DateTime.now().toUtc().toIso8601String(),
        if (!st.logueado) ...{'autor_id': null, 'origen': 'sin_cuenta'},
      };
    }
    try {
      final enviado = await st.publicar(tabla, datos);
      if (!mounted) return;
      if (enviado) {
        Navigator.pop(context);
        avisar('¡Publicado! Tus vecinos ya pueden verlo.');
      } else {
        await _avisoSinConexion(tabla, datos);
      }
    } catch (e) {
      setState(() => _error = traducirError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _avisoSinConexion(String tabla, Map<String, dynamic> datos) async {
    final verQr = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.cloud_off, size: 40),
        title: const Text('Guardado sin internet'),
        content: Text(tabla == 'publicaciones'
            ? 'Quedó guardado en tu celular. Tus vecinos lo verán recién cuando vuelva la señal.\n\n'
                'Si es urgente, muestra el código QR a un vecino que tenga internet: '
                'al escanearlo, su app lo enviará por ti.\n\n'
                'Si hay riesgo de vida, no esperes: llama al 116, 105 o 106.'
            : 'Quedó guardado en tu celular y se enviará cuando vuelva la señal.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Listo')),
          if (tabla == 'publicaciones')
            FilledButton.icon(onPressed: () => Navigator.pop(c, true), icon: const Icon(Icons.qr_code_2), label: const Text('Mostrar QR')),
        ],
      ),
    );
    if (!mounted) return;
    if (verQr == true) {
      await Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MostrarQrScreen(datos: datos)));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final emergenciaPedido = t.esEmergencia && t.tipoPub == 'pido';
    final ubicacionTexto = _buscandoGps && _gps == null
        ? 'Buscando tu ubicación...'
        : _gps != null
            ? 'Tu ubicación actual (GPS)'
            : 'Sector ${_sector ?? Zona.nombre} (aproximado)';

    return Scaffold(
      appBar: AppBar(title: Text(t.titulo)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          if (!st.online)
            const Card(
              color: Color(0xFFFFE082),
              child: ListTile(
                leading: Icon(Icons.cloud_off, color: Colors.black87),
                title: Text('Sin internet: se guardará y podrás compartirlo por QR.', style: TextStyle(color: Colors.black87)),
              ),
            ),
          if (!st.logueado)
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Estás publicando sin cuenta. Solo pedimos tu nombre para que te encuentren.'),
              ),
            ),
          if (t.categorias.length > 1) ...[
            const SizedBox(height: 8),
            const Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in t.categorias)
                ChoiceChip(
                  avatar: Icon(c.icono, size: 20),
                  label: Text(c.nombre),
                  selected: _categoria == c.id,
                  onSelected: (_) => setState(() => _categoria = c.id),
                ),
            ]),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _titulo,
            autofocus: true,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              labelText: t.etiquetaTitulo,
              hintText: t.pista,
              helperText: 'Tip: puedes dictar con el micrófono de tu teclado',
            ),
          ),
          if (emergenciaPedido) ...[
            if (_prioridad == 'critica') const AvisoAutoridades(),
            const SizedBox(height: 8),
            const Text('¿Qué tan urgente es?', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'alta', icon: Icon(Icons.priority_high), label: Text('Urgente')),
                ButtonSegment(value: 'critica', icon: Icon(Icons.warning), label: Text('Riesgo de vida')),
              ],
              selected: {_prioridad},
              onSelectionChanged: (s) => setState(() => _prioridad = s.first),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Expanded(child: Text('¿Cuántas personas?', style: TextStyle(fontWeight: FontWeight.bold))),
              IconButton.filledTonal(
                tooltip: 'Una persona menos',
                onPressed: _personas > 1 ? () => setState(() => _personas--) : null,
                icon: const Icon(Icons.remove),
              ),
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('$_personas', style: Theme.of(context).textTheme.headlineSmall),
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Una persona más',
                onPressed: () => setState(() => _personas++),
                icon: const Icon(Icons.add),
              ),
            ]),
          ],
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(_gps != null ? Icons.my_location : Icons.place),
              title: Text(ubicacionTexto),
              subtitle: Text(t.esServicio
                  ? 'Ayuda a que tus clientes te encuentren'
                  : 'Se mostrará aproximada (±200 m) para cuidar tu privacidad'),
              trailing: TextButton(onPressed: _elegirSector, child: const Text('Cambiar')),
            ),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            initiallyExpanded: t.esServicio || !st.logueado,
            tilePadding: EdgeInsets.zero,
            title: const Text('Más detalles (opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
            children: [
              if (!st.logueado || emergenciaPedido || t == TipoForm.ofrezcoRecurso)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: _nombre,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nombre de contacto', prefixIcon: Icon(Icons.person)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _telefono,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Teléfono o WhatsApp', prefixIcon: Icon(Icons.phone)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _detalle,
                  maxLines: 3,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Detalle',
                    hintText: t.esServicio ? 'Qué ofreces, horario, cantidad...' : 'Qué necesitas, horario, cantidad...',
                    helperText: t.esServicio ? null : 'No escribas tu dirección exacta: compártela por teléfono con quien te ayude.',
                    helperMaxLines: 2,
                  ),
                ),
              ),
              if (t.esServicio) ...[
                if (t == TipoForm.servicio)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _precio,
                      decoration: const InputDecoration(labelText: 'Precio referencial', hintText: 'Ej: Desde S/ 30', prefixIcon: Icon(Icons.payments)),
                    ),
                  ),
                TextField(
                  controller: _horario,
                  decoration: const InputDecoration(labelText: 'Horario de atención', hintText: 'Ej: Lun a Sáb, 8 am a 6 pm', prefixIcon: Icon(Icons.schedule)),
                ),
              ],
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            height: 60,
            child: FilledButton.icon(
              style: t == TipoForm.necesitoAyuda || t == TipoForm.reportarVulnerable
                  ? FilledButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white)
                  : null,
              onPressed: _enviando ? null : _publicar,
              icon: _enviando
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
                  : const Icon(Icons.send),
              label: Text(_enviando ? 'Publicando...' : 'Publicar ahora', style: const TextStyle(fontSize: 20)),
            ),
          ),
        ]),
      ),
    );
  }
}
