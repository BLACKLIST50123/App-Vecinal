import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../ui/tema.dart';

/// "Esto puedes hacer": reemplaza al tutorial de diapositivas. La primera vez
/// se ve grande, con explicación y "Entendido"; después, una fila compacta.
class GuiaInicio extends StatefulWidget {
  const GuiaInicio({super.key, required this.irA});
  final void Function(int tab) irA;

  @override
  State<GuiaInicio> createState() => _GuiaInicioState();
}

class _GuiaInicioState extends State<GuiaInicio> {
  static const _clave = 'guia_vista';
  late bool _vista = context.read<AppState>().prefs.getBool(_clave) ?? false;

  void _entendido() {
    context.read<AppState>().prefs.setBool(_clave, true);
    setState(() => _vista = true);
  }

  @override
  Widget build(BuildContext context) {
    final opciones = [
      (
        Icons.storefront_rounded,
        Paleta.naranja,
        'Servicios y productos',
        'Encuentra gasfiteros, clases, pan y más, cerca de tu casa.',
        1,
      ),
      (
        Icons.volunteer_activism_rounded,
        Paleta.verdeCat,
        'Ayuda entre vecinos',
        'Pide o da una mano, sin dinero: préstamos, favores, colectas.',
        2,
      ),
      (
        Icons.forum_rounded,
        (Paleta.azulInfo, Paleta.azulSuave),
        'Foro',
        'Pregunta y pide recomendaciones a tus vecinos.',
        3,
      ),
    ];

    // Ya vista: los accesos rápidos bajo el buscador hacen ese trabajo.
    if (_vista) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Paleta.superficie,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Paleta.linea),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
          header: true,
          child: Text('Esto puedes hacer', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Paleta.tinta)),
        ),
        const SizedBox(height: 8),
        for (final (icono, (fuerte, suave), titulo, texto, tab) in opciones)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: suave,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => widget.irA(tab),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: Paleta.superficie, shape: BoxShape.circle),
                      child: Icon(icono, color: fuerte, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(titulo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Paleta.tinta)),
                        Text(texto, style: TextStyle(fontSize: 13.5, height: 1.3, color: Paleta.tinta)),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: fuerte),
                  ]),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(Icons.sos_rounded, color: Paleta.rojo, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Emergencia: toca el botón rojo SOS arriba.',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Paleta.rojoTexto)),
            ),
          ]),
        ),
        const SizedBox(height: 6),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: _entendido,
          child: const Text('Entendido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

/// Consejo que sale solo la primera vez en una pestaña, con un botón para
/// hacerlo ya. Se cierra con la X o al tocar el botón, y no vuelve a salir.
class ConsejoPrimeraVez extends StatefulWidget {
  const ConsejoPrimeraVez({
    super.key,
    required this.clave,
    required this.icono,
    required this.colores,
    required this.texto,
    required this.boton,
    required this.alTocar,
  });
  final String clave;
  final IconData icono;
  final (Color, Color) colores;
  final String texto;
  final String boton;
  final VoidCallback alTocar;

  @override
  State<ConsejoPrimeraVez> createState() => _ConsejoPrimeraVezState();
}

class _ConsejoPrimeraVezState extends State<ConsejoPrimeraVez> {
  late bool _visto = context.read<AppState>().prefs.getBool('consejo_${widget.clave}') ?? false;

  void _cerrar() {
    context.read<AppState>().prefs.setBool('consejo_${widget.clave}', true);
    setState(() => _visto = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_visto) return const SizedBox.shrink();
    final (fuerte, suave) = widget.colores;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(color: suave, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(widget.icono, color: fuerte, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.texto, style: TextStyle(fontSize: 14.5, height: 1.3, fontWeight: FontWeight.w700, color: Paleta.tinta)),
            const SizedBox(height: 6),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: fuerte,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 42),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                _cerrar();
                widget.alTocar();
              },
              child: Text(widget.boton, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        IconButton(tooltip: 'Cerrar consejo', onPressed: _cerrar, icon: Icon(Icons.close, color: Paleta.gris)),
      ]),
    );
  }
}
