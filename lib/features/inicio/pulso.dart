import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../screens/confianza.dart';
import '../../state/app_state.dart';
import '../../ui/tema.dart';
import '../../util.dart';

/// Un movimiento del barrio para el pulso (sin nombres).
class EventoPulso {
  const EventoPulso(this.cuando, this.icono, this.texto, {this.propio = false});
  final DateTime cuando;
  final IconData icono;
  final String texto;

  /// Algo tuyo que aún no se envía (sin señal).
  final bool propio;
}

/// Arma los mensajes del pulso a partir de lo que devuelve `Repo.pulso`.
/// Es una función pura para poder probarla.
List<EventoPulso> armarPulso({
  required List<Map<String, dynamic>> apoyos,
  required List<Map<String, dynamic>> publicaciones,
  required List<Map<String, dynamic>> servicios,
  List<String> pendientes = const [],
}) {
  DateTime fecha(dynamic v) => DateTime.tryParse('$v')?.toLocal() ?? DateTime.now();
  String de(dynamic sector) => sector == null || '$sector'.isEmpty ? 'del barrio' : 'de $sector';
  String en(dynamic sector) => sector == null || '$sector'.isEmpty ? '' : ' en $sector';
  String cat(dynamic c, {bool emergencia = false}) => buscarCategoria('$c', emergencia: emergencia).nombre.toLowerCase();

  final eventos = <EventoPulso>[
    for (final t in pendientes)
      EventoPulso(DateTime.now(), Icons.cloud_upload_outlined, 'Tu publicación "$t" se enviará cuando vuelva la señal',
          propio: true),
    for (final a in apoyos)
      if (a['publicaciones'] is Map)
        EventoPulso(
          fecha(a['created_at']),
          Icons.volunteer_activism_rounded,
          (a['publicaciones'] as Map)['es_emergencia'] == true
              ? 'un vecino ${de((a['publicaciones'] as Map)['sector'])} recibió apoyo en la emergencia'
              : 'un vecino ${de((a['publicaciones'] as Map)['sector'])} recibió apoyo: '
                  '${cat((a['publicaciones'] as Map)['categoria'])}',
        ),
    for (final p in publicaciones)
      if (p['es_emergencia'] == true || p['origen'] == 'sos')
        EventoPulso(fecha(p['created_at']), Icons.sos_rounded, 'se reportó una emergencia${en(p['sector'])}')
      else if (p['categoria'] == 'colecta')
        EventoPulso(fecha(p['created_at']), Icons.diversity_1_rounded, 'comenzó una colecta solidaria${en(p['sector'])}')
      else if (p['tipo'] == 'pido')
        EventoPulso(fecha(p['created_at']), Icons.front_hand_rounded,
            'alguien ${de(p['sector'])} pidió ayuda: ${cat(p['categoria'])}')
      else
        EventoPulso(fecha(p['created_at']), Icons.redeem_rounded,
            'un vecino ${de(p['sector'])} ofreció ayuda: ${cat(p['categoria'])}'),
    for (final s in servicios)
      if (s['es_emergencia'] != true)
        EventoPulso(fecha(s['created_at']), Icons.storefront_rounded,
            'se publicó un nuevo servicio: ${cat(s['categoria'])}${en(s['sector'])}'),
  ];
  eventos.sort((a, b) {
    if (a.propio != b.propio) return a.propio ? -1 : 1;
    return b.cuando.compareTo(a.cuando);
  });
  return eventos.take(8).toList();
}

/// "Hace 2 min, un vecino de Bellamar recibió apoyo: préstamo de herramientas".
/// Muestra lo de las últimas 2 horas y se renueva solo cada 2 horas; con señal,
/// lo nuevo entra al instante (tiempo real). Debajo: invitar por WhatsApp.
class PulsoBarrio extends StatefulWidget {
  const PulsoBarrio({super.key});

  @override
  State<PulsoBarrio> createState() => _PulsoBarrioState();
}

class _PulsoBarrioState extends State<PulsoBarrio> {
  static const _horas = 2;
  Timer? _renovar, _rotar;
  int _indice = 0;
  int _version = -1;
  int _vuelta = 0; // sube cada 2 h para volver a consultar
  Future<_DatosPulso>? _futuro;

  @override
  void initState() {
    super.initState();
    _renovar = Timer.periodic(const Duration(hours: _horas), (_) => setState(() => _vuelta++));
    _rotar = Timer.periodic(const Duration(seconds: 5), (_) {
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
    final r = await st.repo.pulso(horas: _horas);
    final eventos = armarPulso(
      apoyos: r.apoyos,
      publicaciones: r.publicaciones,
      servicios: r.servicios,
      pendientes: [for (final e in st.repo.pendientes) e.titulo],
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Paleta.linea)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FutureBuilder<_DatosPulso>(
          future: _futuro,
          builder: (context, s) {
            final d = s.data;
            final eventos = d?.eventos ?? const <EventoPulso>[];
            final enVivo = st.online && (d?.enVivo ?? true);
            Widget linea;
            if (d == null) {
              linea = const _LineaPulso(
                key: ValueKey('cargando'),
                icono: Icons.sensors_rounded,
                texto: 'Mirando qué pasa en tu barrio...',
                activo: false,
              );
            } else if (eventos.isEmpty) {
              linea = const _LineaPulso(
                key: ValueKey('vacio'),
                icono: Icons.wb_sunny_outlined,
                texto: 'Tu barrio está tranquilo. ¡Sé el primero en ayudar!',
                activo: false,
              );
            } else {
              final e = eventos[_indice % eventos.length];
              final texto = e.propio ? e.texto : '${_mayuscula(haceCuanto(e.cuando))}, ${e.texto}';
              linea = _LineaPulso(key: ValueKey('${e.cuando}${e.texto}'), icono: e.icono, texto: texto, activo: enVivo && !e.propio);
            }
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(
                liveRegion: true,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(a), child: child),
                  ),
                  child: linea,
                ),
              ),
              if (d != null && !enVivo)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 30),
                  child: Text(
                    d.actualizado == null ? 'Sin señal' : 'Sin señal · actualizado ${haceCuanto(d.actualizado!)}',
                    style: const TextStyle(fontSize: 12, color: Paleta.gris),
                  ),
                ),
            ]);
          },
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: st.online
              ? OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF128C7E),
                    side: const BorderSide(color: Color(0xFF25D366), width: 1.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => compartirWhatsapp(textoInvitarVecino),
                  icon: const Icon(Icons.share_rounded, size: 19),
                  label: const Text('Invitar por WhatsApp', style: TextStyle(fontWeight: FontWeight.w800)),
                )
              : const OutlinedButton(
                  onPressed: null,
                  child: Text('Necesitas señal para invitar'),
                ),
        ),
      ]),
    );
  }
}

String _mayuscula(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Mensaje para invitar a un vecino (sin números, solo la propuesta).
const textoInvitarVecino = 'Estoy usando Conecta Vecino para ayudarnos entre vecinos de ${Zona.nombre}, '
    'sin dinero y hasta sin internet. ¡Únete! Pídeme el instalador.';

class _DatosPulso {
  _DatosPulso(this.eventos, this.actualizado, this.enVivo);
  final List<EventoPulso> eventos;
  final DateTime? actualizado;
  final bool enVivo;
}

class _LineaPulso extends StatelessWidget {
  const _LineaPulso({super.key, required this.icono, required this.texto, required this.activo});
  final IconData icono;
  final String texto;
  final bool activo;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: Paleta.primarioSuave, borderRadius: BorderRadius.circular(7)),
              child: Icon(icono, size: 15, color: Paleta.primario),
            ),
            if (activo)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(texto,
              maxLines: 3,
              style: const TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w600, color: Paleta.tinta)),
        ),
      ]);
}
