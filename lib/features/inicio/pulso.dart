import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../screens/confianza.dart';
import '../../state/app_state.dart';
import '../../ui/tema.dart';
import '../../util.dart';

/// Tipo de caso de éxito: define el ícono, el color y la etiqueta.
enum TipoExito {
  servicio('Servicios y productos', Icons.storefront_rounded),
  solidaridad('Solidaridad', Icons.volunteer_activism_rounded),
  sos('Emergencia atendida', Icons.health_and_safety_rounded);

  const TipoExito(this.etiqueta, this.icono);
  final String etiqueta;
  final IconData icono;

  Color get color => switch (this) {
        TipoExito.servicio => Paleta.acentoOscuro,
        TipoExito.solidaridad => Paleta.verde,
        TipoExito.sos => Paleta.rojo,
      };
}

/// Un caso de éxito del barrio (sin nombres de vecinos).
class EventoPulso {
  const EventoPulso(this.cuando, this.tipo, this.texto);
  final DateTime cuando;
  final TipoExito tipo;
  final String texto;
}

/// Arma los casos de éxito con textos cortos y los INTERCALA:
/// servicios y productos → solidaridad → emergencia → servicios...
/// Función pura para poder probarla.
List<EventoPulso> armarPulso({
  required List<Map<String, dynamic>> recomendaciones,
  required List<Map<String, dynamic>> agradecimientos,
  required List<Map<String, dynamic>> atendidos,
  Set<String> brigadistas = const {},
}) {
  DateTime fecha(dynamic v) => DateTime.tryParse('$v')?.toLocal() ?? DateTime.now();
  String vecino(dynamic sector) => sector == null || '$sector'.isEmpty ? 'Un vecino' : 'Vecino de $sector';
  String cat(dynamic c, {bool emergencia = false}) => buscarCategoria('$c', emergencia: emergencia).nombre.toLowerCase();
  bool esEmergencia(Map m) => m['origen'] == 'sos' || m['es_emergencia'] == true;
  Map mapa(dynamic v) => v is Map ? v : const {};

  // Quién atendió: un brigadista, una organización, la junta o vecinos.
  String quien(Map p) {
    final rol = mapa(p['atendio'])['rol'];
    if (p['atendido_por'] != null && brigadistas.contains(p['atendido_por'])) return 'un brigadista';
    if (rol == 'organizacion') return 'una organización';
    if (rol == 'moderador') return 'la junta vecinal';
    return 'vecinos';
  }

  final servicios = <EventoPulso>[
    for (final r in recomendaciones)
      if (r['servicios'] is Map)
        EventoPulso(
          fecha(r['created_at']),
          TipoExito.servicio,
          '${vecino(mapa(r['autor'])['sector'])} compró un '
          '${grupoServicio('${(r['servicios'] as Map)['categoria']}') == 'productos' ? 'producto' : 'servicio'} '
          'de ${cat((r['servicios'] as Map)['categoria'])}',
        ),
  ];
  final solidaridad = <EventoPulso>[
    for (final a in agradecimientos)
      if (a['publicaciones'] is Map && !esEmergencia(a['publicaciones'] as Map))
        EventoPulso(fecha(a['created_at']), TipoExito.solidaridad,
            '${vecino((a['publicaciones'] as Map)['sector'])} recibió ayuda: ${cat((a['publicaciones'] as Map)['categoria'])}'),
    for (final p in atendidos)
      if (!esEmergencia(p))
        EventoPulso(fecha(p['created_at']), TipoExito.solidaridad,
            '${vecino(p['sector'])} recibió ayuda: ${cat(p['categoria'])}'),
  ];
  String deVecino(dynamic sector) => sector == null || '$sector'.isEmpty ? 'de un vecino' : 'de un vecino de $sector';
  final emergencias = <EventoPulso>[
    for (final p in atendidos)
      if (esEmergencia(p))
        EventoPulso(fecha(p['created_at']), TipoExito.sos,
            '${p['origen'] == 'sos' ? 'El SOS' : 'El pedido de ayuda'} ${deVecino(p['sector'])} fue atendido por ${quien(p)}'),
    for (final a in agradecimientos)
      if (a['publicaciones'] is Map && esEmergencia(a['publicaciones'] as Map))
        EventoPulso(fecha(a['created_at']), TipoExito.sos,
            'El pedido de ayuda ${deVecino((a['publicaciones'] as Map)['sector'])} fue atendido por vecinos'),
  ];
  for (final l in [servicios, solidaridad, emergencias]) {
    l.sort((a, b) => b.cuando.compareTo(a.cuando));
  }
  // Intercalar: uno de cada tipo, en orden, hasta 9.
  final r = <EventoPulso>[];
  for (var i = 0; r.length < 9; i++) {
    var agregado = false;
    for (final l in [servicios, solidaridad, emergencias]) {
      if (i < l.length && r.length < 9) {
        r.add(l[i]);
        agregado = true;
      }
    }
    if (!agregado) break;
  }
  return r;
}

/// "Buenas noticias del barrio": solo casos de éxito, intercalados por tipo.
/// Muestra las últimas 48 h, se renueva sola cada 2 horas y, con señal, lo
/// nuevo entra al instante (tiempo real).
class PulsoBarrio extends StatefulWidget {
  const PulsoBarrio({super.key});

  @override
  State<PulsoBarrio> createState() => _PulsoBarrioState();
}

class _PulsoBarrioState extends State<PulsoBarrio> {
  Timer? _renovar, _rotar;
  int _indice = 0;
  int _version = -1;
  int _vuelta = 0; // sube cada 2 h para volver a consultar
  Future<_DatosPulso>? _futuro;

  @override
  void initState() {
    super.initState();
    _renovar = Timer.periodic(const Duration(hours: 2), (_) => setState(() => _vuelta++));
    _rotar = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) setState(() => _indice++);
    });
  }

  @override
  void dispose() {
    _renovar?.cancel();
    _rotar?.cancel();
    super.dispose();
  }

  Future<_DatosPulso> _cargar(AppState st) async {
    final r = await st.repo.pulso();
    final eventos = armarPulso(
      recomendaciones: r.recomendaciones,
      agradecimientos: r.agradecimientos,
      atendidos: r.atendidos,
      brigadistas: r.brigadistas,
    );
    return _DatosPulso(eventos, r.actualizado, r.enVivo);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final clave = st.version * 1000 + _vuelta;
    if (_futuro == null || clave != _version) {
      _version = clave;
      _futuro = _cargar(st);
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        // Fondo suave de la paleta (se adapta al modo oscuro).
        color: Paleta.primarioSuave,
        borderRadius: BorderRadius.circular(18),
      ),
      child: FutureBuilder<_DatosPulso>(
        future: _futuro,
        builder: (context, s) {
          final d = s.data;
          final eventos = d?.eventos ?? const <EventoPulso>[];
          final enVivo = st.online && (d?.enVivo ?? true);
          final i = eventos.isEmpty ? 0 : _indice % eventos.length;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: Paleta.acento),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Buenas noticias del barrio',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Paleta.gris)),
              ),
              // Puntitos: cuántos casos hay y cuál se ve.
              for (var k = 0; k < eventos.length; k++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(left: 4),
                  width: k == i ? 14 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: k == i ? eventos[i].tipo.color : Paleta.superficie,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a), child: child),
                ),
                child: d == null
                    ? const _Vacio(key: ValueKey('cargando'), texto: 'Buscando buenas noticias...')
                    : eventos.isEmpty
                        ? const _Vacio(key: ValueKey('vacio'), texto: 'Aún no hay buenas noticias. ¡La próxima puede ser gracias a ti!')
                        : _CasoExito(key: ValueKey('${eventos[i].cuando}${eventos[i].texto}'), evento: eventos[i], enVivo: enVivo),
              ),
            ),
            if (d != null && !enVivo)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  d.actualizado == null ? 'Sin señal' : 'Sin señal · actualizado ${haceCuanto(d.actualizado!)}',
                  style: TextStyle(fontSize: 12, color: Paleta.gris),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

/// Un caso de éxito: ícono en un círculo suave del color de su tipo,
/// etiqueta, texto corto y hace cuánto.
class _CasoExito extends StatelessWidget {
  const _CasoExito({super.key, required this.evento, required this.enVivo});
  final EventoPulso evento;
  final bool enVivo;

  @override
  Widget build(BuildContext context) {
    final t = evento.tipo;
    return Row(children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: Paleta.superficie, shape: BoxShape.circle),
        child: Icon(t.icono, color: t.color, size: 24),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(evento.texto,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w700, color: Paleta.tinta)),
          const SizedBox(height: 3),
          Row(children: [
            Text(t.etiqueta, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: t.color)),
            Text(' · ${haceCuanto(evento.cuando)}', style: TextStyle(fontSize: 12, color: Paleta.gris)),
            if (enVivo) ...[
              const SizedBox(width: 6),
              Container(width: 6, height: 6, decoration: BoxDecoration(color: Paleta.verde, shape: BoxShape.circle)),
            ],
          ]),
        ]),
      ),
    ]);
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({super.key, required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: Paleta.acentoSuave, shape: BoxShape.circle),
          child: Icon(Icons.wb_sunny_outlined, color: Paleta.acentoOscuro, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(texto, style: TextStyle(fontSize: 14, height: 1.3, fontWeight: FontWeight.w600, color: Paleta.tinta)),
        ),
      ]);
}

/// Botón verde para invitar a un vecino por WhatsApp (va al final del Inicio).
class BotonInvitarWhatsapp extends StatelessWidget {
  const BotonInvitarWhatsapp({super.key});

  static Color get _verde => Paleta.whatsapp;

  @override
  Widget build(BuildContext context) {
    final online = context.select<AppState, bool>((s) => s.online);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: SizedBox(
        height: 54,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _verde,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Paleta.lineaFuerte,
            disabledForegroundColor: Paleta.gris,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: online ? () => compartirWhatsapp(textoInvitarVecino) : null,
          icon: const Icon(Icons.share_rounded),
          label: Text(online ? 'Invitar vecinos por WhatsApp' : 'Necesitas señal para invitar',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}


/// Mensaje para invitar a un vecino (sin números, solo la propuesta).
const textoInvitarVecino = 'Estoy usando Conecta Vecino para ayudarnos entre vecinos de ${Zona.nombre}, '
    'sin dinero y hasta sin internet. ¡Únete! Pídeme el instalador.';

class _DatosPulso {
  _DatosPulso(this.eventos, this.actualizado, this.enVivo);
  final List<EventoPulso> eventos;
  final DateTime? actualizado;
  final bool enVivo;
}
