import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';
import 'auth_screen.dart';
import 'detalles.dart';

// ================================================================ compartir

/// Comparte por WhatsApp (el canal que los vecinos ya usan).
Future<void> compartirWhatsapp(String texto) async {
  try {
    await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(texto)}'), mode: LaunchMode.externalApplication);
  } catch (_) {
    avisar('No se pudo abrir WhatsApp');
  }
}

String textoCompartir(Publicacion p) =>
    '${p.esEmergencia ? '🚨 ' : ''}Vecino${p.sector != null ? ' de ${p.sector}' : ''} '
    '${p.esPedido ? 'necesita' : 'ofrece'}: "${p.titulo}". '
    '${p.esPedido ? '¿Puedes ayudar? ' : ''}Míralo en App Vecinal ${Zona.nombre}.';

const textoInvitacion = 'Únete a App Vecinal ${Zona.nombre}: encuentra servicios y productos recomendados por tus vecinos, '
    'pide o presta cosas sin dinero y coordina ayuda en emergencias, incluso sin internet. Pídeme el instalador 📲';

// ================================================================== normas

const normasBarrio = <(IconData, String, String)>[
  (Icons.handshake, 'Respeto', 'Trata a todos por igual. No se permiten mensajes por apariencia, origen, edad o condición económica.'),
  (Icons.gavel, 'Nada de acusaciones', 'No acuses a nadie de un delito. Si ves algo grave, llama a la Policía (105).'),
  (Icons.fact_check, 'Información verdadera', 'Publica solo lo que sabes que es cierto. Las alarmas falsas quitan ayuda a quien la necesita.'),
  (Icons.privacy_tip, 'Cuida los datos', 'No publiques direcciones exactas, ni quién vive solo, ni fotos de otras personas sin permiso.'),
  (Icons.local_police, 'La app no reemplaza a las autoridades', 'En riesgo de vida llama primero a Bomberos 116, Policía 105 o SAMU 106.'),
  (Icons.flag, 'Reporta lo que esté mal', 'Si algo es falso, una estafa u ofensivo, usa "Reportar". Con 3 reportes se oculta.'),
];

Future<void> mostrarNormas(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          builder: (c, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
            Semantics(
              header: true,
              child: Text('Normas del barrio', style: Theme.of(c).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            ),
            BotonEscuchar(normasBarrio.map((n) => '${n.$2}. ${n.$3}').join(' ')),
            for (final (icono, titulo, texto) in normasBarrio)
              ListTile(
                leading: Icon(icono, size: 32),
                title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(texto, style: const TextStyle(fontSize: 16)),
              ),
          ]),
        ),
      ),
    );

// ================================================================ reportar

const motivosReporte = <(String, String, IconData)>[
  ('falso', 'Es falso o una emergencia que no existe', Icons.report),
  ('estafa', 'Parece una estafa', Icons.money_off),
  ('discriminacion', 'Discrimina u ofende', Icons.do_not_disturb_on),
  ('acusacion', 'Acusa a alguien sin pruebas', Icons.gavel),
  ('datos_personales', 'Expone datos o la dirección de alguien', Icons.privacy_tip),
  ('otro', 'Otro motivo', Icons.more_horiz),
];

Future<void> reportarContenido(BuildContext context, {required String tabla, required String id, required String titulo}) async {
  final st = context.read<AppState>();
  if (!st.logueado) {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => const AuthScreen(mensaje: 'Para reportar necesitas una cuenta de vecino (así evitamos reportes falsos).'),
    ));
    return;
  }
  final motivo = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: ListView(shrinkWrap: true, children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('¿Qué problema tiene?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        for (final (id, texto, icono) in motivosReporte)
          ListTile(leading: Icon(icono), title: Text(texto), onTap: () => Navigator.pop(c, id)),
      ]),
    ),
  );
  if (motivo == null) return;
  try {
    await st.repo.reportar(tabla: tabla, id: id, titulo: titulo, motivo: motivo);
    avisar('Gracias. La junta vecinal lo revisará. Con 3 reportes se oculta automáticamente.');
    st.refrescar();
  } catch (e) {
    avisar(traducirError(e).contains('ya estaba') ? 'Ya habías reportado esta publicación.' : traducirError(e));
  }
}

// ============================================== aviso: no reemplaza autoridades

class AvisoAutoridades extends StatelessWidget {
  const AvisoAutoridades({super.key});

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFFFF3E0),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.info, color: Color(0xFFE65100)),
              SizedBox(width: 8),
              Expanded(
                child: Text('Esta app coordina ayuda entre vecinos. No reemplaza a las autoridades.',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            ]),
            const SizedBox(height: 4),
            const Text('Si hay riesgo de vida, llama primero:', style: TextStyle(color: Colors.black87)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (nombre, numero, icono) in numerosEmergencia)
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white),
                  onPressed: () => llamar(numero),
                  icon: Icon(icono),
                  label: Text('$nombre $numero'),
                ),
            ]),
          ]),
        ),
      );
}

// ======================================================== panel de coordinación

/// Para organizaciones y junta vecinal: indicadores de impacto, pedidos
/// priorizados por estado y reportes por revisar.
class PanelCoordinacionScreen extends StatefulWidget {
  const PanelCoordinacionScreen({super.key});

  @override
  State<PanelCoordinacionScreen> createState() => _PanelCoordinacionScreenState();
}

class _PanelCoordinacionScreenState extends State<PanelCoordinacionScreen> {
  String _filtro = 'abierta';
  int _recarga = 0;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final emergencia = st.modoEmergencia;
    return Scaffold(
      appBar: AppBar(title: const Text('Panel de coordinación')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _recarga++);
          st.refrescar();
        },
        child: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(emergencia ? 'Emergencia en curso' : 'Cadena de favores (día a día)',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Cargador<Map<String, int>>(
            claves: [emergencia, _recarga],
            cargar: (st) => st.repo.indicadores(emergencia: emergencia),
            builder: (c, i) {
              final total = i['total']!;
              final atendidos = i['resuelta']!;
              final pct = total == 0 ? 0 : (atendidos * 100 / total).round();
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  _Indicador('Pendientes', i['abierta']!, const Color(0xFFE65100), Icons.hourglass_top),
                  _Indicador('En atención', i['en_curso']!, const Color(0xFF1565C0), Icons.directions_run),
                  _Indicador('Atendidos', atendidos, const Color(0xFF2E7D32), Icons.check_circle),
                  _Indicador('No verificados', i['no_verificado']!, const Color(0xFF616161), Icons.help),
                  _Indicador('Verificados', i['verificadas']!, const Color(0xFF00695C), Icons.verified),
                  _Indicador('Vecinos ayudando', i['ayudantes']!, const Color(0xFF6A1B9A), Icons.volunteer_activism),
                  _Indicador('% resuelto', pct, const Color(0xFF2E7D32), Icons.trending_up, sufijo: '%'),
                ]),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'abierta', label: Text('Pendientes')),
                ButtonSegment(value: 'en_curso', label: Text('En atención')),
                ButtonSegment(value: 'no_verificado', label: Text('No verif.')),
              ],
              selected: {_filtro},
              onSelectionChanged: (s) => setState(() => _filtro = s.first),
            ),
          ),
          Cargador<List<Publicacion>>(
            claves: [emergencia, _filtro, _recarga],
            cargar: (st) => st.repo.publicaciones(emergencia: emergencia),
            builder: (c, lista) {
              final filtrada = lista.where((p) => p.estado == _filtro && p.esPedido).toList()
                ..sort((a, b) {
                  final x = b.pesoPrioridad.compareTo(a.pesoPrioridad);
                  return x != 0 ? x : a.creado.compareTo(b.creado); // los más antiguos primero
                });
              if (filtrada.isEmpty) {
                return const EstadoVacio(icono: Icons.inbox, texto: 'No hay pedidos en este estado.');
              }
              return Column(children: [for (final p in filtrada) TarjetaPublicacion(p)]);
            },
          ),
          if (st.esModerador) ...[
            const TituloSeccion('Reportes por revisar'),
            Cargador<List<Map<String, dynamic>>>(
              claves: [_recarga],
              cargar: (st) => st.repo.reportesPendientes(),
              builder: (c, reportes) {
                if (reportes.isEmpty) {
                  return const EstadoVacio(icono: Icons.verified_user, texto: 'No hay reportes pendientes.');
                }
                final porObjeto = <String, List<Map<String, dynamic>>>{};
                for (final r in reportes) {
                  porObjeto.putIfAbsent('${r['tabla']}|${r['objeto_id']}', () => []).add(r);
                }
                return Column(children: [
                  for (final e in porObjeto.entries)
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: e.value.length >= 3 ? const Color(0xFFB71C1C) : const Color(0xFFFFE0B2),
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
                              setState(() => _recarga++);
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
            ),
          ],
        ]),
      ),
    );
  }
}

class _Indicador extends StatelessWidget {
  const _Indicador(this.texto, this.valor, this.color, this.icono, {this.sufijo = ''});
  final String texto;
  final int valor;
  final Color color;
  final IconData icono;
  final String sufijo;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$texto: $valor$sufijo',
        excludeSemantics: true,
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icono, color: color),
            Text('$valor$sufijo', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
            Text(texto, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
