import 'dart:async';

import 'package:flutter/material.dart';

import '../../models.dart';
import '../../screens/detalles.dart';
import '../../ui/tema.dart';
import '../../util.dart';
import 'sos_navegacion.dart';

/// Botón SOS de la cabecera. Cuando llega una emergencia nueva cerca
/// (alertaEntrante), late suavemente y muestra un punto blanco.
class BotonSosCabecera extends StatefulWidget {
  const BotonSosCabecera({super.key});

  @override
  State<BotonSosCabecera> createState() => _BotonSosCabeceraState();
}

class _BotonSosCabeceraState extends State<BotonSosCabecera> with SingleTickerProviderStateMixin {
  late final AnimationController _latido =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    alertaEntrante.addListener(_alCambiar);
    _alCambiar();
  }

  void _alCambiar() {
    if (alertaEntrante.value != null) {
      _latido.repeat(reverse: true);
    } else {
      _latido
        ..stop()
        ..value = 0;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    alertaEntrante.removeListener(_alCambiar);
    _latido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hayAlerta = alertaEntrante.value != null;
    return Tooltip(
      message: hayAlerta ? 'Emergencia nueva cerca · SOS' : 'SOS · Auxilio rápido',
      child: Semantics(
        button: true,
        label: hayAlerta ? 'SOS. Hay una emergencia nueva cerca.' : 'SOS. Abrir auxilio rápido.',
        excludeSemantics: true,
        child: AnimatedBuilder(
          animation: _latido,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_latido.value);
            return Transform.scale(
              scale: 1 + 0.08 * t,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Paleta.rojo.withValues(alpha: hayAlerta ? 0.25 + 0.35 * t : 0.3),
                      blurRadius: hayAlerta ? 6 + 10 * t : 4,
                      spreadRadius: hayAlerta ? 1 + 3 * t : 0,
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: Material(
            color: Paleta.rojo,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: abrirSos,
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.crisis_alert_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    const Text('SOS',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.8)),
                    if (hayAlerta) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso bajo la cabecera: "Emergencia nueva a 350 m · Ver". Se cierra solo
/// a los 45 s, al tocar la X o al abrir el detalle.
class AvisoEmergenciaNueva extends StatefulWidget {
  const AvisoEmergenciaNueva({super.key});

  @override
  State<AvisoEmergenciaNueva> createState() => _AvisoEmergenciaNuevaState();
}

class _AvisoEmergenciaNuevaState extends State<AvisoEmergenciaNueva> {
  Timer? _cierre;
  String? _id;

  @override
  void initState() {
    super.initState();
    alertaEntrante.addListener(_alCambiar);
    _alCambiar();
  }

  void _alCambiar() {
    final a = alertaEntrante.value;
    if (a != null && a.$1.id != _id) {
      _id = a.$1.id;
      _cierre?.cancel();
      _cierre = Timer(const Duration(seconds: 45), _cerrar);
    }
    if (a == null) _id = null;
    if (mounted) setState(() {});
  }

  void _cerrar() => alertaEntrante.value = null;

  @override
  void dispose() {
    alertaEntrante.removeListener(_alCambiar);
    _cierre?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = alertaEntrante.value;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: a == null ? const SizedBox(width: double.infinity) : _franja(context, a.$1, a.$2),
    );
  }

  Widget _franja(BuildContext context, Publicacion p, double km) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Semantics(
          liveRegion: true,
          label: 'Emergencia nueva ${formatoDistancia(km)}: ${p.titulo}',
          child: Material(
            color: Paleta.rojoSuave,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                _cerrar();
                Navigator.push(context, MaterialPageRoute(builder: (_) => PublicacionDetalle(publicacion: p)));
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Paleta.rojo.withValues(alpha: 0.5)),
                ),
                child: Row(children: [
                  const Icon(Icons.campaign_rounded, color: Paleta.rojo, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Emergencia nueva ${formatoDistancia(km)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Paleta.rojoTexto)),
                      Text(p.titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: Paleta.tinta)),
                    ]),
                  ),
                  const Text('Ver', style: TextStyle(fontWeight: FontWeight.w800, color: Paleta.rojo)),
                  IconButton(
                    tooltip: 'Cerrar aviso',
                    visualDensity: VisualDensity.compact,
                    onPressed: _cerrar,
                    icon: const Icon(Icons.close_rounded, size: 20, color: Paleta.gris),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}
