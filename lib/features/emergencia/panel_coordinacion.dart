import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config.dart';
import '../../data/datos_iniciales.dart';
import '../../models.dart';
import '../../screens/confianza.dart';
import '../../screens/detalles.dart';
import '../../state/app_state.dart';
import '../../ui/diseno.dart';
import '../../ui/tema.dart';
import '../../ui/widgets.dart';
import '../../util.dart';
import '../junta/junta.dart';

/// Separa los SOS: los de esta emergencia (desde que se activó) y los
/// anteriores. Ambos del más reciente al más antiguo. Función pura.
({List<Publicacion> ahora, List<Publicacion> antes}) separarSos(List<Publicacion> sos, {DateTime? desde}) {
  final orden = [...sos]..sort((a, b) => b.creado.compareTo(a.creado));
  if (desde == null) return (ahora: <Publicacion>[], antes: orden);
  final d = desde.toLocal();
  return (
    ahora: [for (final p in orden) if (!p.creado.isBefore(d)) p],
    antes: [for (final p in orden) if (p.creado.isBefore(d)) p],
  );
}

/// SOS (botón rojo) o Necesito ayuda (pedido de emergencia).
String _tipoAviso(Publicacion p) => p.origen == 'sos' ? 'SOS' : 'Necesito ayuda';

/// Mensaje listo para derivar un SOS a las autoridades o al grupo de brigadistas.
String textoDerivarSos(Publicacion p) {
  final tipo = _tipoAviso(p).toUpperCase();
  final cat = buscarCategoria(p.categoria, emergencia: true).nombre;
  final mapa = p.punto == null ? '' : '\nUbicación aproximada: https://maps.google.com/?q=${p.punto!.lat},${p.punto!.lng}';
  return '$tipo · $cat\n${p.titulo}\n'
      '${p.sector != null ? 'Sector ${p.sector} · ' : ''}${Zona.nombre}\n'
      'Enviado: ${fechaHora(p.creado)}'
      '${p.contactoTelefono != null ? '\nContacto: ${p.contactoTelefono}' : ''}'
      '$mapa\n— Junta vecinal, vía Conecta Vecino';
}

/// Panel de coordinación (junta, organizaciones y brigadistas): solo los SOS,
/// con fecha y hora exactas, para que alguien ACTÚE: derivar a autoridades,
/// asignar a un brigadista, llamar, ir y cambiar el estado.
class PanelCoordinacionScreen extends StatelessWidget {
  const PanelCoordinacionScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pedidos y SOS')),
        body: const PanelSos(),
      );
}

/// Contenido del panel. En emergencia es la 3.ª pestaña del moderador.
class PanelSos extends StatefulWidget {
  const PanelSos({super.key});

  @override
  State<PanelSos> createState() => _PanelSosState();
}

class _PanelSosState extends State<PanelSos> {
  bool _anteriores = false; // por defecto: la emergencia actual

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final hayEmergencia = st.modoEmergencia;
    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: Cargador<List<Publicacion>>(
        claves: [st.emergencia.clave],
        cargar: (st) => st.repo.sosParaCoordinar(),
        builder: (context, sos) {
          final g = separarSos(sos, desde: hayEmergencia ? st.emergencia.desde : null);
          // Sin emergencia activa no hay "actual": se ven los últimos 7 días.
          final verAnteriores = !hayEmergencia || _anteriores;
          final lista = verAnteriores ? g.antes : g.ahora;
          return ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            if (hayEmergencia)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(minimumSize: const Size(0, 48)),
                  segments: [
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.crisis_alert_rounded, size: 18),
                      label: Text('Emergencia actual (${g.ahora.length})'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.history_rounded, size: 18),
                      label: Text('Anteriores (${g.antes.length})'),
                    ),
                  ],
                  selected: {_anteriores},
                  onSelectionChanged: (s) => setState(() => _anteriores = s.first),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Text(
                !hayEmergencia
                    ? 'Pedidos de ayuda y SOS de los últimos 7 días. Toca uno para derivarlo a las autoridades, asignarlo a un brigadista o cambiar su estado.'
                    : _anteriores
                        ? 'Enviados antes de que se activara esta emergencia, del más reciente al más antiguo.'
                        : 'Enviados desde que se activó la emergencia, del más reciente al más antiguo. Toca uno para actuar.',
                style: const TextStyle(fontSize: 14, color: Paleta.gris),
              ),
            ),
            if (lista.isEmpty)
              _Vacio(verAnteriores ? 'No hay pedidos anteriores.' : 'Nadie ha pedido ayuda desde que se activó la emergencia.')
            else
              for (final p in lista) _TarjetaSos(p),
            if (st.esModerador) const _ReportesPorRevisar(),
          ]);
        },
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(texto, style: const TextStyle(color: Paleta.gris)));
}

(String, Color) _estadoSos(Publicacion p) => switch (p.estado) {
      'resuelta' => ('Atendido', const Color(0xFF15803D)),
      'en_curso' => ('En atención', const Color(0xFF1D4ED8)),
      'no_verificado' => ('Falsa alarma', Paleta.gris),
      _ => ('Sin atender', Paleta.rojo),
    };

class _TarjetaSos extends StatelessWidget {
  const _TarjetaSos(this.p);
  final Publicacion p;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final cat = buscarCategoria(p.categoria, emergencia: true);
    final (estado, color) = _estadoSos(p);
    final abierto = p.estado == 'abierta' || p.estado == 'en_curso';
    final km = p.punto == null ? null : distanciaKm(st.referencia, p.punto!);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: abierto && p.estado == 'abierta' ? Paleta.rojo.withValues(alpha: 0.5) : Paleta.linea),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => abrirAccionesSos(context, p),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: Paleta.rojoSuave, borderRadius: BorderRadius.circular(12)),
              child: Icon(cat.icono, color: Paleta.rojo),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text('${_tipoAviso(p)} · ${cat.nombre}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Paleta.tinta)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                    child: Text(estado, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(_fechaExacta(p.creado), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Paleta.tinta)),
                Text(
                  [
                    if (p.sector != null) p.sector!,
                    if (km != null) formatoDistancia(km),
                    p.autorNombre ?? 'Vecino',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Paleta.gris),
                ),
                if (p.atendidoPor != null && p.estado == 'en_curso')
                  const Text('Asignado a un brigadista',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8))),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Paleta.grisClaro),
          ]),
        ),
      ),
    );
  }
}

/// "Sáb 8 nov 2026 · 14:32" (fecha y hora exactas).
String _fechaExacta(DateTime t) {
  const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  final l = t.toLocal();
  final hh = l.hour.toString().padLeft(2, '0');
  final mm = l.minute.toString().padLeft(2, '0');
  return '${dias[l.weekday - 1]} ${l.day} ${meses[l.month - 1]} ${l.year} · $hh:$mm';
}

/// Acciones sobre un SOS. Derivar, llamar e ir: todos los que coordinan.
/// Asignar y cambiar estado: junta y organizaciones (lo permite la base).
Future<void> abrirAccionesSos(BuildContext context, Publicacion p) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _AccionesSos(p),
    );

class _AccionesSos extends StatelessWidget {
  const _AccionesSos(this.p);
  final Publicacion p;

  Future<void> _abrir(Uri u) async {
    try {
      await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {
      avisar('No se pudo abrir.');
    }
  }

  Future<void> _estado(BuildContext context, String estado, String texto) async {
    final st = context.read<AppState>();
    try {
      await st.repo.cambiarEstado(p.id, estado);
      st.refrescar();
      if (context.mounted) Navigator.pop(context);
      avisar(texto);
    } catch (e) {
      avisar(traducirError(e));
    }
  }

  Future<void> _asignar(BuildContext context) async {
    final st = context.read<AppState>();
    final sector = p.sector ?? st.sector;
    if (sector == null) {
      avisar('Este SOS no tiene sector. Derívalo a las autoridades o al grupo de brigadistas.');
      return;
    }
    List<Brigadista> brigadistas;
    try {
      brigadistas = (await st.repo.brigadistasSector(sector)).where((b) => b.activo).toList();
    } catch (e) {
      avisar(traducirError(e));
      return;
    }
    if (!context.mounted) return;
    if (brigadistas.isEmpty) {
      avisar('No hay brigadistas activos en $sector. La junta puede nombrarlos en su panel.');
      return;
    }
    final elegido = await showModalBottomSheet<Brigadista>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Brigadistas de $sector', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          for (final b in brigadistas)
            ListTile(
              leading: Icon(especialidadBrigadista(b.especialidad).$3, color: Paleta.rojo),
              title: Text(b.nombre ?? 'Brigadista'),
              subtitle: Text(b.especialidadNombre),
              onTap: () => Navigator.pop(c, b),
            ),
        ]),
      ),
    );
    if (elegido == null || !context.mounted) return;
    final ok = await confirmar(
      context,
      titulo: '¿Asignar este SOS a ${elegido.nombre ?? 'este brigadista'}?',
      mensaje: 'Lo verá como "Asignado a ti" en su panel y el SOS pasará a "En atención".',
      accion: 'Sí, asignar',
    );
    if (!ok) return;
    try {
      await st.repo.asignarSos(p.id, elegido.vecinoId);
      st.refrescar();
      if (context.mounted) Navigator.pop(context);
      avisar('SOS asignado a ${elegido.nombre ?? 'el brigadista'}.');
    } catch (e) {
      avisar(traducirError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final puedeGestionar = st.esModerador || st.esOrganizacion;
    final cat = buscarCategoria(p.categoria, emergencia: true);
    final (estado, color) = _estadoSos(p);
    final tel = p.contactoTelefono?.trim();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(cat.icono, color: Paleta.rojo, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_tipoAviso(p)} · ${cat.nombre}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                Text('${_fechaExacta(p.creado)} · $estado', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
          const SizedBox(height: 6),
          Text(p.titulo, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 16),

          // 1 ─ Derivar a autoridades (lo más importante en una emergencia real)
          const Text('Derivar a las autoridades', style: TextStyle(fontWeight: FontWeight.w800, color: Paleta.tinta)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final n in DatosIniciales.actual.numeros)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Paleta.rojo),
                onPressed: () => llamar(n.numero),
                icon: Icon(n.icono, size: 18),
                label: Text('${n.nombre} ${n.numero}'),
              ),
          ]),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => compartirWhatsapp(textoDerivarSos(p)),
            icon: const Icon(Icons.share_rounded),
            label: const Text('Enviar los datos por WhatsApp'),
          ),
          const Text('Para Serenazgo, la comisaría o el grupo de brigadistas: incluye tipo, sector, hora y ubicación.',
              style: TextStyle(fontSize: 12, color: Paleta.gris)),
          const SizedBox(height: 14),

          // 2 ─ Actuar en el barrio
          if (puedeGestionar && (p.estado == 'abierta' || p.estado == 'en_curso')) ...[
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: () => _asignar(context),
                icon: const Icon(Icons.health_and_safety_rounded),
                label: const Text('Asignar a un brigadista'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(children: [
            if (tel != null && tel.isNotEmpty) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _abrir(Uri.parse('tel:${tel.replaceAll(RegExp(r'[^0-9+]'), '')}')),
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('Llamar al vecino'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (p.punto != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _abrir(Uri.parse(
                      'https://www.google.com/maps/dir/?api=1&destination=${p.punto!.lat},${p.punto!.lng}')),
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('Cómo llegar'),
                ),
              ),
          ]),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicacionDetalle(publicacion: p))),
            child: const Text('Ver detalle completo'),
          ),

          // 3 ─ Estado
          if (puedeGestionar) ...[
            const Divider(height: 24),
            const Text('Cambiar estado', style: TextStyle(fontWeight: FontWeight.w800, color: Paleta.tinta)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (p.estado != 'en_curso')
                ActionChip(
                  avatar: const Icon(Icons.directions_run_rounded, size: 18),
                  label: const Text('En atención'),
                  onPressed: () => _estado(context, 'en_curso', 'SOS en atención.'),
                ),
              if (p.estado != 'resuelta')
                ActionChip(
                  avatar: const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF15803D)),
                  label: const Text('Atendido'),
                  onPressed: () => _estado(context, 'resuelta', 'SOS atendido. Ya no aparece en el mapa.'),
                ),
              if (p.estado != 'no_verificado')
                ActionChip(
                  avatar: const Icon(Icons.block_rounded, size: 18),
                  label: const Text('Falsa alarma'),
                  onPressed: () => _estado(context, 'no_verificado', 'Marcado como falsa alarma.'),
                ),
              if (p.estado != 'abierta')
                ActionChip(
                  avatar: const Icon(Icons.undo_rounded, size: 18),
                  label: const Text('Reabrir'),
                  onPressed: () => _estado(context, 'abierta', 'SOS reabierto.'),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// Contenido denunciado por los vecinos (solo la junta).
class _ReportesPorRevisar extends StatelessWidget {
  const _ReportesPorRevisar();

  @override
  Widget build(BuildContext context) => Cargador<List<Map<String, dynamic>>>(
        cargar: (st) => st.repo.reportesPendientes(),
        builder: (context, reportes) {
          final st = context.read<AppState>();
          final porObjeto = <String, List<Map<String, dynamic>>>{};
          for (final r in reportes) {
            porObjeto.putIfAbsent('${r['tabla']}|${r['objeto_id']}', () => []).add(r);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TituloDiseno('Reportes por revisar', detalle: '${porObjeto.length}'),
            if (porObjeto.isEmpty)
              const _Vacio('No hay reportes pendientes.')
            else
              for (final e in porObjeto.entries)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: e.value.length >= 3 ? Paleta.rojo : Paleta.ambarSuave,
                      child: Text('${e.value.length}',
                          style: TextStyle(color: e.value.length >= 3 ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                    ),
                    title: Text((e.value.first['titulo'] ?? 'Publicación') as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(e.value
                        .map((r) => motivosReporte.firstWhere((m) => m.$1 == r['motivo'], orElse: () => motivosReporte.last).$2)
                        .toSet()
                        .join(' · ')),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Acciones',
                      onSelected: (accion) async {
                        final (tabla, id) = (e.key.split('|')[0], e.key.split('|')[1]);
                        try {
                          if (accion == 'eliminar') await st.repo.eliminar(tabla, id);
                          await st.repo.marcarReportesRevisados(tabla, id);
                          avisar(accion == 'eliminar' ? 'Contenido eliminado' : 'Reportes descartados');
                          st.refrescar();
                        } catch (err) {
                          avisar(traducirError(err));
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'eliminar', child: Text('Eliminar contenido')),
                        PopupMenuItem(value: 'descartar', child: Text('Descartar reportes')),
                      ],
                    ),
                  ),
                ),
          ]);
        },
      );
}
