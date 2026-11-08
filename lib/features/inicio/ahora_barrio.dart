import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../state/app_state.dart';
import '../../ui/tema.dart';
import '../../util.dart';

/// "Ahora en tu barrio": un movimiento reciente del barrio (sin nombres).
/// Va arriba del Inicio; "Buenas noticias" (pulso.dart) va más abajo.
class EventoAhora {
  const EventoAhora(this.cuando, this.icono, this.texto, {this.propio = false});
  final DateTime cuando;
  final IconData icono;
  final String texto;

  /// Algo tuyo que aún no se envía (sin señal).
  final bool propio;
}

/// Arma los mensajes del pulso a partir de lo que devuelve `Repo.pulso`.
/// Es una función pura para poder probarla.
List<EventoAhora> armarAhora({
  required List<Map<String, dynamic>> apoyos,
  required List<Map<String, dynamic>> publicaciones,
  required List<Map<String, dynamic>> servicios,
  List<String> pendientes = const [],
}) {
  DateTime fecha(dynamic v) => DateTime.tryParse('$v')?.toLocal() ?? DateTime.now();
  String de(dynamic sector) => sector == null || '$sector'.isEmpty ? 'del barrio' : 'de $sector';
  String en(dynamic sector) => sector == null || '$sector'.isEmpty ? '' : ' en $sector';
  String cat(dynamic c, {bool emergencia = false}) => buscarCategoria('$c', emergencia: emergencia).nombre.toLowerCase();

  final eventos = <EventoAhora>[
    for (final t in pendientes)
      EventoAhora(DateTime.now(), Icons.cloud_upload_outlined, 'Tu publicación "$t" se enviará cuando vuelva la señal',
          propio: true),
    for (final a in apoyos)
      if (a['publicaciones'] is Map)
        EventoAhora(
          fecha(a['created_at']),
          Icons.volunteer_activism_rounded,
          (a['publicaciones'] as Map)['es_emergencia'] == true
              ? 'un vecino ${de((a['publicaciones'] as Map)['sector'])} recibió apoyo en la emergencia'
              : 'un vecino ${de((a['publicaciones'] as Map)['sector'])} recibió apoyo: '
                  '${cat((a['publicaciones'] as Map)['categoria'])}',
        ),
    for (final p in publicaciones)
      if (p['es_emergencia'] == true || p['origen'] == 'sos')
        EventoAhora(fecha(p['created_at']), Icons.sos_rounded, 'se reportó una emergencia${en(p['sector'])}')
      else if (p['categoria'] == 'colecta')
        EventoAhora(fecha(p['created_at']), Icons.diversity_1_rounded, 'comenzó una colecta solidaria${en(p['sector'])}')
      else if (p['tipo'] == 'pido')
        EventoAhora(fecha(p['created_at']), Icons.front_hand_rounded,
            'alguien ${de(p['sector'])} pidió ayuda: ${cat(p['categoria'])}')
      else
        EventoAhora(fecha(p['created_at']), Icons.redeem_rounded,
            'un vecino ${de(p['sector'])} ofreció ayuda: ${cat(p['categoria'])}'),
    for (final s in servicios)
      if (s['es_emergencia'] != true)
        EventoAhora(fecha(s['created_at']), Icons.storefront_rounded,
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
class AhoraEnTuBarrio extends StatefulWidget {
  const AhoraEnTuBarrio({super.key});

  @override
  State<AhoraEnTuBarrio> createState() => _AhoraEnTuBarrioState();
}

class _AhoraEnTuBarrioState extends State<AhoraEnTuBarrio> {
  static const _horas = 2;
  Timer? _renovar, _rotar;
  int _indice = 0;
  int _version = -1;
  int _vuelta = 0; // sube cada 2 h para volver a consultar
  Future<_DatosAhora>? _futuro;

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

  Future<_DatosAhora> _cargar(AppState st) async {
    final r = await st.repo.actividadReciente(horas: _horas);
    final eventos = armarAhora(
      apoyos: r.apoyos,
      publicaciones: r.publicaciones,
      servicios: r.servicios,
      pendientes: [for (final e in st.repo.pendientes) e.titulo],
    );
    return _DatosAhora(eventos, r.actualizado, r.enVivo);
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [Color(0xFF1E293B), Color(0xFF334155)], // banda marino en ambos temas
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.sensors_rounded, size: 16, color: Paleta.verdeClaro),
          SizedBox(width: 6),
          Text('AHORA EN TU BARRIO',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: Paleta.lineaFuerte)),
        ]),
        const SizedBox(height: 8),
        FutureBuilder<_DatosAhora>(
          future: _futuro,
          builder: (context, s) {
            final d = s.data;
            final eventos = d?.eventos ?? const <EventoAhora>[];
            final enVivo = st.online && (d?.enVivo ?? true);
            Widget linea;
            if (d == null) {
              linea = const _LineaAhora(
                key: ValueKey('cargando'),
                icono: Icons.sensors_rounded,
                texto: 'Mirando qué pasa en tu barrio...',
                activo: false,
              );
            } else if (eventos.isEmpty) {
              linea = const _LineaAhora(
                key: ValueKey('vacio'),
                icono: Icons.wb_sunny_outlined,
                texto: 'Tu barrio está tranquilo. ¡Sé el primero en ayudar!',
                activo: false,
              );
            } else {
              final e = eventos[_indice % eventos.length];
              final texto = e.propio ? e.texto : '${_mayuscula(haceCuanto(e.cuando))}, ${e.texto}';
              linea = _LineaAhora(key: ValueKey('${e.cuando}${e.texto}'), icono: e.icono, texto: texto, activo: enVivo && !e.propio);
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
                    style: TextStyle(fontSize: 12, color: Paleta.lineaFuerte),
                  ),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}

class _DatosAhora {
  _DatosAhora(this.eventos, this.actualizado, this.enVivo);
  final List<EventoAhora> eventos;
  final DateTime? actualizado;
  final bool enVivo;
}

class _LineaAhora extends StatelessWidget {
  const _LineaAhora({super.key, required this.icono, required this.texto, required this.activo});
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
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(7)),
              child: Icon(icono, size: 15, color: Colors.white),
            ),
            if (activo)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Paleta.verde,
                    shape: BoxShape.circle,
                    border: Border.all(color: Paleta.primario, width: 1.5),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(texto,
              maxLines: 3,
              style: const TextStyle(fontSize: 16, height: 1.3, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ]);
}

String _mayuscula(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
