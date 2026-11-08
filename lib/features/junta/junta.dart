import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models.dart';
import '../../screens/detalles.dart';
import '../../state/app_state.dart';
import '../../ui/diseno.dart';
import '../../ui/tema.dart';
import '../../ui/widgets.dart';

// ======================================================= panel de la junta

/// Panel de la junta vecinal: nombra brigadistas entre los vecinos de SU
/// sector y publica los canales de comunicación del sector.
class PanelJuntaScreen extends StatelessWidget {
  const PanelJuntaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final sector = st.sector;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(sector == null ? 'Junta vecinal' : 'Junta vecinal · $sector'),
          bottom: const TabBar(tabs: [Tab(text: 'Vecinos'), Tab(text: 'Brigadistas'), Tab(text: 'Canales')]),
        ),
        body: sector == null
            ? const EstadoVacio(
                icono: Icons.location_off_outlined,
                texto: 'Tu cuenta de junta aún no tiene sector. Pide que lo asignen para gestionar a tus vecinos.',
              )
            : Cargador<(List<MiembroSector>, List<Brigadista>, List<CanalSector>)>(
                claves: [sector],
                cargar: (st) async => (
                  await st.repo.miembrosSector(sector),
                  await st.repo.brigadistasSector(sector),
                  await st.repo.canalesSector(sector),
                ),
                builder: (context, d) => TabBarView(children: [
                  _TabVecinos(sector: sector, miembros: d.$1, brigadistas: d.$2),
                  _TabBrigadistas(brigadistas: d.$2),
                  _TabCanales(sector: sector, canales: d.$3),
                ]),
              ),
      ),
    );
  }
}

class _TabVecinos extends StatefulWidget {
  const _TabVecinos({required this.sector, required this.miembros, required this.brigadistas});
  final String sector;
  final List<MiembroSector> miembros;
  final List<Brigadista> brigadistas;

  @override
  State<_TabVecinos> createState() => _TabVecinosState();
}

class _TabVecinosState extends State<_TabVecinos> {
  String _buscar = '';

  Future<void> _nombrar(MiembroSector m) async {
    final st = context.read<AppState>();
    final especialidad = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => _ElegirEspecialidad(nombre: m.nombre),
    );
    if (especialidad == null || !mounted) return;
    final ok = await confirmar(
      context,
      titulo: '¿Nombrar a ${m.nombre} como brigadista?',
      mensaje: 'Especialidad: ${especialidadBrigadista(especialidad).$2}.\n'
          '${m.nombre} recibirá la invitación y debe aceptarla para ser brigadista de ${widget.sector}.',
      accion: 'Sí, nombrar',
    );
    if (!ok) return;
    try {
      await st.repo.nombrarBrigadista(vecinoId: m.id, sector: widget.sector, especialidad: especialidad);
      st.refrescar();
      avisar('Listo. ${m.nombre} recibirá tu invitación.');
    } catch (e) {
      avisar(traducirError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final yaNombrados = {for (final b in widget.brigadistas) b.vecinoId: b};
    final lista = widget.miembros.where((m) => m.nombre.toLowerCase().contains(_buscar.toLowerCase())).toList();
    return ListView(padding: const EdgeInsets.only(bottom: 40), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text('${widget.miembros.length} vecinos registrados en ${widget.sector}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Paleta.tinta)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: TextField(
          onChanged: (v) => setState(() => _buscar = v),
          decoration: const InputDecoration(hintText: 'Buscar vecino por nombre', prefixIcon: Icon(Icons.search)),
        ),
      ),
      if (lista.isEmpty)
        const EstadoVacio(icono: Icons.group_outlined, texto: 'No hay vecinos con ese nombre en tu sector.')
      else
        ListaAjustes(filas: [
          for (final m in lista)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: Paleta.primarioSuave,
                  child: Text(iniciales(m.nombre), style: const TextStyle(fontWeight: FontWeight.w800, color: Paleta.primario)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Row(children: [
                      Icon(m.verificado ? Icons.verified_user : Icons.gpp_maybe_outlined,
                          size: 14, color: m.verificado ? const Color(0xFF2E7D32) : Paleta.gris),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          '${m.verificado ? 'Verificado' : 'Sin verificar'} · ${Nivel.de(m.ayudas).nombre}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Paleta.gris),
                        ),
                      ),
                    ]),
                  ]),
                ),
                if (yaNombrados[m.id] != null)
                  _Estado(yaNombrados[m.id]!)
                else
                  TextButton(onPressed: () => _nombrar(m), child: const Text('Hacer brigadista')),
              ]),
            ),
        ]),
    ]);
  }
}

class _ElegirEspecialidad extends StatelessWidget {
  const _ElegirEspecialidad({required this.nombre});
  final String nombre;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('¿En qué apoyará $nombre?', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          for (final e in especialidadesBrigadista)
            ListTile(
              leading: Icon(e.$3, color: Paleta.primario),
              title: Text(e.$2),
              onTap: () => Navigator.pop(context, e.$1),
            ),
          const SizedBox(height: 8),
        ]),
      );
}

class _Estado extends StatelessWidget {
  const _Estado(this.b);
  final Brigadista b;

  @override
  Widget build(BuildContext context) {
    final color = b.activo ? const Color(0xFF2E7D32) : const Color(0xFFB45309);
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
      child: Text(b.activo ? 'Brigadista' : 'Invitado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

class _TabBrigadistas extends StatelessWidget {
  const _TabBrigadistas({required this.brigadistas});
  final List<Brigadista> brigadistas;

  Future<void> _quitar(BuildContext context, Brigadista b) async {
    final st = context.read<AppState>();
    final nombre = b.nombre ?? 'este vecino';
    final ok = await confirmar(
      context,
      titulo: '¿Quitar a $nombre como brigadista?',
      mensaje: 'Dejará de ver el panel de alertas y los canales privados de brigadistas. Podrás nombrarlo de nuevo cuando quieras.',
      accion: 'Sí, quitar',
      peligro: true,
    );
    if (!ok) return;
    try {
      await st.repo.quitarBrigadista(b.vecinoId);
      st.refrescar();
      avisar('$nombre ya no es brigadista.');
    } catch (e) {
      avisar(traducirError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (brigadistas.isEmpty) {
      return const EstadoVacio(
        icono: Icons.health_and_safety_outlined,
        texto: 'Aún no hay brigadistas. Nómbralos desde la pestaña Vecinos.',
      );
    }
    final orden = [...brigadistas]..sort((a, b) => a.activo == b.activo ? 0 : (a.activo ? -1 : 1));
    return ListView(padding: const EdgeInsets.only(top: 10, bottom: 40), children: [
      ListaAjustes(filas: [
        for (final b in orden)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Paleta.rojoSuave, borderRadius: BorderRadius.circular(12)),
                child: Icon(especialidadBrigadista(b.especialidad).$3, color: Paleta.rojo, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.nombre ?? 'Vecino', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('${b.especialidadNombre} · ${b.activo ? 'Activo' : 'Esperando que acepte'}',
                      style: TextStyle(fontSize: 12, color: b.activo ? const Color(0xFF2E7D32) : const Color(0xFFB45309))),
                ]),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Paleta.rojo),
                onPressed: () => _quitar(context, b),
                child: const Text('Quitar'),
              ),
            ]),
          ),
      ]),
    ]);
  }
}

class _TabCanales extends StatelessWidget {
  const _TabCanales({required this.sector, required this.canales});
  final String sector;
  final List<CanalSector> canales;

  Future<void> _agregar(BuildContext context) async {
    final st = context.read<AppState>();
    final canal = await showModalBottomSheet<CanalSector>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _FormCanal(sector: sector),
    );
    if (canal == null) return;
    try {
      await st.repo.guardarCanal(canal);
      st.refrescar();
      avisar('Canal agregado.');
    } catch (e) {
      avisar(traducirError(e));
    }
  }

  Future<void> _borrar(BuildContext context, CanalSector c) async {
    final st = context.read<AppState>();
    final ok = await confirmar(context, titulo: '¿Quitar "${c.etiqueta}"?', mensaje: 'Los vecinos dejarán de verlo.', accion: 'Quitar', peligro: true);
    if (!ok || c.id == null) return;
    try {
      await st.repo.borrarCanal(c.id!);
      st.refrescar();
    } catch (e) {
      avisar(traducirError(e));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.only(top: 10, bottom: 40), children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Text(
            'Los canales públicos los ven todos los vecinos del sector. Los de brigadistas solo los ven ellos: '
            'la coordinación privada sigue fuera de la app.',
            style: TextStyle(fontSize: 13, color: Paleta.gris),
          ),
        ),
        if (canales.isEmpty)
          const EstadoVacio(icono: Icons.forum_outlined, texto: 'Aún no hay canales. Agrega el grupo de WhatsApp del barrio.')
        else
          ListaAjustes(filas: [
            for (final c in canales)
              ListTile(
                leading: Icon(c.icono, color: Paleta.primario),
                title: Text(c.etiqueta, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${c.tipoNombre} · ${c.publico ? 'Público' : 'Solo brigadistas'}\n${c.valor}', maxLines: 3),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Quitar canal',
                  onPressed: () => _borrar(context, c),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
          ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: FilledButton.icon(
            onPressed: () => _agregar(context),
            icon: const Icon(Icons.add),
            label: const Text('Agregar canal'),
          ),
        ),
      ]);
}

class _FormCanal extends StatefulWidget {
  const _FormCanal({required this.sector});
  final String sector;

  @override
  State<_FormCanal> createState() => _FormCanalState();
}

class _FormCanalState extends State<_FormCanal> {
  String _tipo = 'whatsapp';
  bool _publico = true;
  final _etiqueta = TextEditingController();
  final _valor = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _etiqueta.dispose();
    _valor.dispose();
    super.dispose();
  }

  String get _pista => switch (_tipo) {
        'whatsapp' => 'https://chat.whatsapp.com/...',
        'telegram' => 'https://t.me/...',
        'telefono' => '987654321',
        'reunion' => 'Ej: Sábados 6 pm, local comunal',
        _ => 'Enlace o dato',
      };

  void _guardar() {
    final etiqueta = _etiqueta.text.trim();
    final valor = _valor.text.trim();
    String? error;
    if (etiqueta.length < 2) {
      error = 'Escribe un nombre para el canal.';
    } else if (_tipo == 'whatsapp' && !(valor.startsWith('https://chat.whatsapp.com/') || valor.startsWith('https://wa.me/'))) {
      error = 'Pega el enlace de invitación del grupo de WhatsApp.';
    } else if (_tipo == 'telegram' && !valor.startsWith('https://t.me/')) {
      error = 'Pega el enlace de Telegram (https://t.me/...).';
    } else if (_tipo == 'telefono' && !RegExp(r'^\+?\d{6,12}$').hasMatch(valor.replaceAll(' ', ''))) {
      error = 'Escribe un número válido.';
    } else if (valor.length < 2) {
      error = 'Completa el dato del canal.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(
      context,
      CanalSector(sector: widget.sector, tipo: _tipo, etiqueta: etiqueta, valor: valor, publico: _publico),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Nuevo canal del sector', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in const [('whatsapp', 'WhatsApp'), ('telefono', 'Teléfono'), ('reunion', 'Reuniones'), ('telegram', 'Telegram')])
              ChoiceChip(label: Text(t.$2), selected: _tipo == t.$1, onSelected: (_) => setState(() => _tipo = t.$1)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _etiqueta,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej: Grupo de vecinos Bellamar'),
          ),
          TextField(
            controller: _valor,
            keyboardType: _tipo == 'telefono' ? TextInputType.phone : TextInputType.text,
            decoration: InputDecoration(labelText: 'Enlace o dato', hintText: _pista, errorText: _error),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: !_publico,
            onChanged: (v) => setState(() => _publico = !v),
            title: const Text('Solo para brigadistas'),
            subtitle: const Text('Los vecinos no lo verán.'),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _guardar, child: const Text('Guardar canal')),
        ]),
      );
}

// ================================================================ vecino

/// Invitación de la junta: "Te nombró brigadista" con Aceptar / Ahora no.
class TarjetaNombramiento extends StatefulWidget {
  const TarjetaNombramiento({super.key});

  @override
  State<TarjetaNombramiento> createState() => _TarjetaNombramientoState();
}

class _TarjetaNombramientoState extends State<TarjetaNombramiento> {
  bool _ocupado = false;

  Future<void> _responder(bool aceptar) async {
    final st = context.read<AppState>();
    if (!aceptar) {
      final ok = await confirmar(
        context,
        titulo: '¿Rechazar la invitación?',
        mensaje: 'La junta podrá invitarte de nuevo más adelante.',
        accion: 'Sí, rechazar',
      );
      if (!ok) return;
    }
    setState(() => _ocupado = true);
    try {
      await st.responderNombramiento(aceptar);
      avisar(aceptar ? '¡Gracias! Ya eres brigadista de tu sector.' : 'Listo, rechazaste la invitación.');
    } catch (e) {
      avisar(traducirError(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final b = st.brigadista;
    if (!st.tieneInvitacionBrigadista || b == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Paleta.rojoSuave,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Paleta.rojo.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.health_and_safety_rounded, color: Paleta.rojo, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('La junta vecinal de ${b.sector} te nombró brigadista',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Paleta.tinta)),
              Text('Especialidad: ${b.especialidadNombre}', style: const TextStyle(fontSize: 13, color: Paleta.gris)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        const Text(
          'Como brigadista verás las alertas SOS de tu zona y los canales de coordinación de la junta.',
          style: TextStyle(fontSize: 13, color: Paleta.tinta),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(onPressed: _ocupado ? null : () => _responder(false), child: const Text('Ahora no')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Paleta.rojo),
              onPressed: _ocupado ? null : () => _responder(true),
              child: const Text('Aceptar'),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// "Tu junta vecinal": canales del sector para tocar y abrir.
class TarjetaMiJunta extends StatelessWidget {
  const TarjetaMiJunta({super.key});

  Future<void> _abrir(CanalSector c) async {
    final u = c.enlace;
    if (u == null) return;
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {
      avisar('No se pudo abrir el canal.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final sector = st.sector;
    if (sector == null) return const SizedBox.shrink();
    return Cargador<List<CanalSector>>(
      claves: [sector, st.esBrigadista],
      cargar: (st) => st.repo.canalesSector(sector),
      builder: (context, canales) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TituloDiseno('Tu junta vecinal', detalle: sector),
        if (canales.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Tu junta aún no ha publicado sus canales de comunicación.', style: TextStyle(color: Paleta.gris)),
          )
        else
          ListaAjustes(filas: [
            for (final c in canales)
              ListTile(
                leading: Icon(c.icono, color: c.publico ? Paleta.primario : Paleta.rojo),
                title: Text(c.etiqueta, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(c.publico ? (c.enlace == null ? c.valor : c.tipoNombre) : 'Solo brigadistas · ${c.tipoNombre}'),
                trailing: c.enlace == null ? null : const Icon(Icons.open_in_new_rounded, size: 20),
                onTap: c.enlace == null ? null : () => _abrir(c),
              ),
          ]),
      ]),
    );
  }
}

/// Distintivo "Brigadista de Bellamar · Primeros auxilios".
class InsigniaBrigadista extends StatelessWidget {
  const InsigniaBrigadista(this.b, {super.key});
  final Brigadista b;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Paleta.rojoSuave, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.health_and_safety_rounded, size: 13, color: Paleta.rojo),
          const SizedBox(width: 4),
          Flexible(
            child: Text('Brigadista de ${b.sector} · ${b.especialidadNombre}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFB71C1C))),
          ),
        ]),
      );
}

// ============================================================== utilidades

/// Ventana de confirmación (nombrar, quitar, rechazar...).
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String accion,
  bool peligro = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(
            style: peligro ? FilledButton.styleFrom(backgroundColor: Paleta.rojo) : null,
            onPressed: () => Navigator.pop(c, true),
            child: Text(accion),
          ),
        ],
      ),
    ) ??
    false;
