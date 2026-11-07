import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/voz.dart';
import '../state/app_state.dart';

class _Paso {
  const _Paso(this.icono, this.titulo, this.texto);
  final IconData icono;
  final String titulo;
  final String texto;
}

const _pasos = [
  _Paso(Icons.diversity_3, 'Bienvenido a App Vecinal',
      'Tu barrio en el celular: encuentra ayuda, ofrece lo que sabes y apóyate en tus vecinos de Chimbote.'),
  _Paso(Icons.thumb_up, 'Servicios y productos con Visto Bueno',
      'Busca gasfiteros, clases, pan, bodegas y más cerca de tu casa. Los vecinos verificados que ya los usaron les dan su Visto Bueno.'),
  _Paso(Icons.volunteer_activism, 'Favores y solidaridad',
      'Pide una mano o da lo que te sobra: presta, regala, enseña, acompaña a un adulto mayor o aporta a una colecta. Todo sin dinero, entre vecinos.'),
  _Paso(Icons.touch_app, 'Publica en 3 toques',
      'Toca Publicar, elige qué quieres y toca Publicar ahora. Tu ubicación y contacto ya están puestos.'),
  _Paso(Icons.sos, 'En una emergencia',
      'La app cambia a rojo. Toca NECESITO AYUDA, incluso sin cuenta. Si no hay internet, comparte tu pedido por QR con un vecino.'),
];

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, this.inicial = false});

  /// true cuando se muestra al primer ingreso (no se puede "volver").
  final bool inicial;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _control = PageController();
  int _pagina = 0;

  void _terminar() {
    Voz.callar();
    final st = context.read<AppState>();
    st.marcarTutorial(true);
    if (!widget.inicial) Navigator.pop(context);
    st.ubicar();
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final ultimo = _pagina == _pasos.length - 1;
    final esquema = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _terminar, child: const Text('Saltar')),
          ),
          Expanded(
            child: PageView.builder(
              controller: _control,
              itemCount: _pasos.length,
              onPageChanged: (i) {
                Voz.callar();
                setState(() => _pagina = i);
              },
              itemBuilder: (_, i) {
                final p = _pasos[i];
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(children: [
                    const SizedBox(height: 24),
                    CircleAvatar(
                      radius: 72,
                      backgroundColor: esquema.primaryContainer,
                      child: Icon(p.icono, size: 80, color: esquema.onPrimaryContainer),
                    ),
                    const SizedBox(height: 32),
                    Semantics(
                      header: true,
                      child: Text(p.titulo, textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    Text(p.texto, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => Voz.hablar('${p.titulo}. ${p.texto}'),
                      icon: const Icon(Icons.volume_up),
                      label: const Text('Escuchar'),
                    ),
                    if (i == 0) ...[
                      const SizedBox(height: 24),
                      const Text('Elige el tamaño de letra:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SegmentedButton<double>(
                        segments: const [
                          ButtonSegment(value: 1.0, label: Text('A')),
                          ButtonSegment(value: 1.3, label: Text('A+')),
                          ButtonSegment(value: 1.6, label: Text('A++')),
                        ],
                        selected: {st.escala},
                        onSelectionChanged: (s) => st.setEscala(s.first),
                      ),
                    ],
                  ]),
                );
              },
            ),
          ),
          Semantics(
            label: 'Paso ${_pagina + 1} de ${_pasos.length}',
            excludeSemantics: true,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < _pasos.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  width: i == _pagina ? 24 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: i == _pagina ? esquema.primary : esquema.outlineVariant,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: ultimo
                    ? _terminar
                    : () => _control.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
                child: Text(ultimo ? 'Empezar' : 'Siguiente', style: const TextStyle(fontSize: 20)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
