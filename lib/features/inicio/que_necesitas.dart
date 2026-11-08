import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config.dart';
import '../../data/sugerencias.dart';
import '../../services/dictado.dart';
import '../../state/app_state.dart';
import '../../ui/tema.dart';
import '../../ui/widgets.dart';
import '../sos/sos_navegacion.dart';
import 'necesidad.dart';

typedef IrAPestana = void Function(int tab, {String? grupo, String? consulta});

/// La puerta principal del Inicio: la persona escribe o dice lo que necesita
/// y la app la lleva a la pestaña correcta con su búsqueda ya escrita.
/// Solo si suena a emergencia se queda aquí y ofrece el SOS.
class QueNecesitas extends StatefulWidget {
  const QueNecesitas({super.key, required this.irA});
  final IrAPestana irA;

  @override
  State<QueNecesitas> createState() => _QueNecesitasState();
}

class _QueNecesitasState extends State<QueNecesitas> {
  final _texto = TextEditingController();
  bool _escuchando = false;
  bool _emergencia = false;

  // Ejemplos rotativos: muestran servicios, favores y el foro para orientar
  // al vecino sobre todo lo que puede pedir aquí.
  static const _ejemplos = [
    'un gasfitero cerca',
    'pan recién horneado',
    'clases de refuerzo escolar',
    'prestar una escalera',
    'alguien que cuide mi mascota',
    '¿alguien conoce un electricista?',
    'menú casero del día',
    'ayuda para cargar algo',
  ];
  int _ejemplo = 0;
  Timer? _rotar;

  @override
  void initState() {
    super.initState();
    _rotar = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && _texto.text.isEmpty) setState(() => _ejemplo = (_ejemplo + 1) % _ejemplos.length);
    });
  }

  @override
  void dispose() {
    _rotar?.cancel();
    Dictado.soltar();
    _texto.dispose();
    super.dispose();
  }

  void _buscar([String? t]) {
    final v = (t ?? _texto.text).trim();
    if (v.isEmpty) {
      avisar('Escribe o di lo que necesitas');
      return;
    }
    FocusScope.of(context).unfocus();
    final n = interpretarNecesidad(v);
    switch (n.destino) {
      case DestinoNecesidad.emergencia:
        setState(() => _emergencia = true);
        return;
      case DestinoNecesidad.solidaridad:
        widget.irA(2, grupo: 'pedir', consulta: v);
      case DestinoNecesidad.foro:
        // En el foro se busca por el oficio si se reconoce ("electricista" → electricidad).
        widget.irA(3, consulta: sugerirCategoria(v, [for (final c in categoriasServicio) c.id]) ?? v);
      case DestinoNecesidad.servicio:
        widget.irA(1, consulta: buscarCategoria(n.categoria!).nombre.toLowerCase());
      case DestinoNecesidad.buscar:
        widget.irA(1, consulta: v.toLowerCase());
    }
    _texto.clear();
  }

  Future<void> _dictar() async {
    if (_escuchando) {
      await Dictado.detener();
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    final ok = await Dictado.escuchar(
      alTexto: (texto, esFinal) {
        if (!mounted || texto.isEmpty) return;
        final limpio = texto[0].toUpperCase() + texto.substring(1);
        _texto.value = TextEditingValue(text: limpio, selection: TextSelection.collapsed(offset: limpio.length));
        if (esFinal) _buscar(limpio);
      },
      alCambiar: (v) {
        if (mounted && v != _escuchando) setState(() => _escuchando = v);
      },
    );
    if (!ok && mounted) avisar('Este celular no permite dictar aquí. Escribe lo que necesitas.');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          header: true,
          child: Text('¿Qué necesitas hoy?',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Paleta.tinta, letterSpacing: -0.3)),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _texto,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _buscar(),
              onChanged: (_) => setState(() => _emergencia = false),
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Ej: ${_ejemplos[_ejemplo]}',
                hintMaxLines: 1,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _texto.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Buscar',
                        icon: const Icon(Icons.arrow_forward_rounded),
                        onPressed: _buscar,
                      ),
                filled: true,
                fillColor: Paleta.superficie,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Paleta.lineaFuerte)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Paleta.acentoOscuro, width: 2)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: _escuchando ? 'Dejar de escuchar' : 'Decirlo con la voz',
            excludeSemantics: true,
            child: Material(
              color: _escuchando ? Paleta.rojo : Paleta.acentoOscuro,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _dictar,
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(
                    _escuchando ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ]),
        if (_escuchando)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Te escucho… habla con calma.',
                style: TextStyle(color: Paleta.rojoTexto, fontWeight: FontWeight.w700)),
          ),
        // Chips de acceso rápido: orientan al vecino sin necesidad de un
        // panel guía separado. Se ocultan mientras dicta o hay emergencia.
        if (!_escuchando && !_emergencia) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _ChipAcceso(
                icono: Icons.storefront_rounded,
                label: 'Servicios',
                color: Paleta.acentoOscuro,
                onTap: () => widget.irA(1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ChipAcceso(
                icono: Icons.volunteer_activism_rounded,
                label: 'Ayuda vecinal',
                color: const Color(0xFF397158),
                onTap: () => widget.irA(2, grupo: 'pedir'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ChipAcceso(
                icono: Icons.forum_rounded,
                label: 'Foro',
                color: const Color(0xFF1565C0),
                onTap: () => widget.irA(3),
              ),
            ),
          ]),
        ],
        if (_emergencia)
          _Emergencia(alNoEs: () {
            setState(() => _emergencia = false);
            final v = _texto.text.trim();
            if (v.isNotEmpty) widget.irA(1, consulta: v.toLowerCase());
            _texto.clear();
          }),
      ]),
    );
  }
}

/// Chip compacto de acceso rápido debajo del buscador.
class _ChipAcceso extends StatelessWidget {
  const _ChipAcceso({
    required this.icono,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icono;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fondo = color.withValues(alpha: 0.10);
    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icono, size: 18, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Suena a emergencia: primero preguntar, con el SOS a un toque.
class _Emergencia extends StatelessWidget {
  const _Emergencia({required this.alNoEs});
  final VoidCallback alNoEs;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Paleta.rojoSuave,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Paleta.rojo.withValues(alpha: 0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.warning_amber_rounded, color: Paleta.rojo, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Text('¿Es una emergencia?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Paleta.rojoTexto)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('Si hay riesgo de vida, avisa a tus vecinos con el SOS o llama a los bomberos.',
              style: TextStyle(fontSize: 14, color: Paleta.tinta, height: 1.3)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Paleta.rojo,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  abrirSos();
                },
                icon: const Icon(Icons.sos_rounded),
                label: const Text('SOS', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Paleta.rojoTexto,
                  side: BorderSide(color: Paleta.rojo),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => llamar('116'),
                icon: const Icon(Icons.call_rounded),
                label: const Text('Llamar 116', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
          TextButton(onPressed: alNoEs, child: const Text('No es una emergencia, buscar')),
        ]),
      );
}
