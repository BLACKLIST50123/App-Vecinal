import 'dart:async';

import 'package:flutter/material.dart';

import '../../models.dart';
import '../../screens/detalles.dart';
import '../../ui/tema.dart';
import '../../util.dart';
import 'sos_navegacion.dart';

/// Botón SOS de la cabecera. Cuenta con un efecto de respiración y aura
/// luminosa constante para rápida identificación, y se acelera con latido
/// urgente cuando hay una emergencia activa reportada en el barrio.
class BotonSosCabecera extends StatefulWidget {
  const BotonSosCabecera({super.key});

  @override
  State<BotonSosCabecera> createState() => _BotonSosCabeceraState();
}

class _BotonSosCabeceraState extends State<BotonSosCabecera>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controlador;
  bool _presionado = false;

  @override
  void initState() {
    super.initState();
    _controlador = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _ajustarAnimacion();
    alertaEntrante.addListener(_alCambiarAlerta);
  }

  void _ajustarAnimacion() {
    final hayAlerta = alertaEntrante.value != null;
    _controlador.duration = Duration(milliseconds: hayAlerta ? 650 : 1800);
    if (!_controlador.isAnimating) {
      _controlador.repeat(reverse: true);
    }
  }

  void _alCambiarAlerta() {
    _ajustarAnimacion();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    alertaEntrante.removeListener(_alCambiarAlerta);
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hayAlerta = alertaEntrante.value != null;
    return Tooltip(
      message: hayAlerta
          ? 'Emergencia nueva cerca · SOS'
          : 'SOS · Auxilio rápido',
      child: Semantics(
        button: true,
        label: hayAlerta
            ? 'SOS. Hay una emergencia nueva cerca.'
            : 'SOS. Abrir auxilio rápido.',
        excludeSemantics: true,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _presionado = true),
          onTapUp: (_) => setState(() => _presionado = false),
          onTapCancel: () => setState(() => _presionado = false),
          child: AnimatedBuilder(
            animation: _controlador,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_controlador.value);
              final escalaPulso = 1.0 + (hayAlerta ? 0.08 : 0.035) * t;
              final escalaTouch = _presionado ? 0.94 : 1.0;
              final escalaTotal = escalaPulso * escalaTouch;

              return Transform.scale(
                scale: escalaTotal,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      // Halo exterior brillante tipo radar / aura
                      BoxShadow(
                        color: Paleta.rojo.withValues(
                          alpha: hayAlerta ? 0.35 + 0.40 * t : 0.22 + 0.26 * t,
                        ),
                        blurRadius: hayAlerta ? 8 + 14 * t : 6 + 9 * t,
                        spreadRadius: hayAlerta ? 2 + 4 * t : 0.5 + 2.5 * t,
                      ),
                      // Sombra base suave para dar profundidad
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        offset: const Offset(0, 3),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: child,
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFC62828)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: abrirSos,
                  child: SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _controlador,
                            builder: (context, _) {
                              final t = Curves.easeInOut.transform(
                                _controlador.value,
                              );
                              return Transform.scale(
                                scale: 1.0 + (hayAlerta ? 0.16 : 0.08) * t,
                                child: const Icon(
                                  Icons.crisis_alert_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (hayAlerta) ...[
                            const SizedBox(width: 6),
                            AnimatedBuilder(
                              animation: _controlador,
                              builder: (context, _) {
                                final t = Curves.easeInOut.transform(
                                  _controlador.value,
                                );
                                return Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(
                                          alpha: 0.5 + 0.5 * t,
                                        ),
                                        blurRadius: 4 + 4 * t,
                                        spreadRadius: 1 * t,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
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
      child: a == null
          ? const SizedBox(width: double.infinity)
          : _franja(context, a.$1, a.$2),
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PublicacionDetalle(publicacion: p),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Paleta.rojo.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.campaign_rounded,
                  color: Paleta.rojo,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergencia nueva ${formatoDistancia(km)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFB71C1C),
                        ),
                      ),
                      Text(
                        p.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Paleta.tinta,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Ver',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Paleta.rojo,
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar aviso',
                  visualDensity: VisualDensity.compact,
                  onPressed: _cerrar,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Paleta.gris,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
