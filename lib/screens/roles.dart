import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../ui/tema.dart';

/// Un perfil que el usuario puede elegir (o simular) al abrir la app.
class RolInfo {
  const RolInfo(this.id, this.titulo, this.subtitulo, this.descripcion, this.icono, this.color);
  final String id;
  final String titulo;
  final String subtitulo;
  final String descripcion;
  final IconData icono;
  final Color color;
}

const roles = <RolInfo>[
  RolInfo(
    'vecino',
    'Vecino / Ciudadano',
    'Rol estándar',
    'Publica trueques, ofrece ayuda, comenta en el foro y usa el botón de emergencia.',
    Icons.home_outlined,
    Paleta.primario,
  ),
  RolInfo(
    'brigadista',
    'Brigadista / Líder comunitario',
    'Punto focal en emergencias',
    'Coordinas la ayuda humanitaria y el reparto de recursos cuando se activa el modo crítico. Recibes las alertas SOS.',
    Icons.health_and_safety_outlined,
    Paleta.rojo,
  ),
];

RolInfo infoRol(String id) => roles.firstWhere((r) => r.id == id, orElse: () => roles.first);

/// Pantalla "¿Quién soy hoy?": se muestra al abrir la app y desde el perfil.
class SelectorRolScreen extends StatefulWidget {
  const SelectorRolScreen({super.key, this.inicial = true});

  /// true al abrir la app (no hay pantalla a la cual volver).
  final bool inicial;

  @override
  State<SelectorRolScreen> createState() => _SelectorRolScreenState();
}

class _SelectorRolScreenState extends State<SelectorRolScreen> {
  late String _rol;

  @override
  void initState() {
    super.initState();
    _rol = context.read<AppState>().rolSimulado;
  }

  void _entrar() {
    context.read<AppState>().elegirRol(_rol);
    if (!widget.inicial) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final elegido = infoRol(_rol);
    return Scaffold(
      appBar: widget.inicial ? null : AppBar(title: const Text('Cambiar de rol')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 32), children: [
          if (widget.inicial) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: Paleta.primario, borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.diversity_3, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 18),
          ],
          const Text('Bienvenido a App Vecinal',
              style: TextStyle(color: Paleta.acentoOscuro, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Semantics(
            header: true,
            child: const Text('¿Quién soy hoy?',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.1)),
          ),
          const SizedBox(height: 8),
          const Text('Elige cómo quieres usar la app. Puedes cambiarlo cuando quieras desde tu perfil.',
              style: TextStyle(color: Paleta.gris, fontSize: 15, height: 1.4)),
          const SizedBox(height: 22),
          for (final r in roles) ...[
            _TarjetaRol(info: r, seleccionado: r.id == _rol, onTap: () => setState(() => _rol = r.id)),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: elegido.color, minimumSize: const Size.fromHeight(56)),
            onPressed: _entrar,
            child: Text('Entrar como ${elegido.titulo.split(' /').first}'),
          ),
        ]),
      ),
    );
  }
}

class _TarjetaRol extends StatelessWidget {
  const _TarjetaRol({required this.info, required this.seleccionado, required this.onTap});
  final RolInfo info;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: seleccionado,
        button: true,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: seleccionado ? info.color : Paleta.linea, width: seleccionado ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: info.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(15)),
                  child: Icon(info.icono, color: info.color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(info.subtitulo.toUpperCase(),
                        style: TextStyle(color: info.color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                    Text(info.titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(info.descripcion, style: const TextStyle(color: Paleta.gris, fontSize: 14, height: 1.35)),
                  ]),
                ),
                const SizedBox(width: 8),
                Icon(seleccionado ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: seleccionado ? info.color : Paleta.grisClaro),
              ]),
            ),
          ),
        ),
      );
}

/// Píldora con el rol actual (se muestra en Inicio y Perfil).
class PildoraRol extends StatelessWidget {
  const PildoraRol({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final r = infoRol(st.rolSimulado);
    final texto = r.titulo.split(' /').first;
    return Material(
      color: r.color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectorRolScreen(inicial: false))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(r.icono, size: 18, color: r.color),
            const SizedBox(width: 6),
            Text(texto, style: TextStyle(color: r.color, fontWeight: FontWeight.w700, fontSize: 14)),
            Icon(Icons.swap_horiz, size: 18, color: r.color),
          ]),
        ),
      ),
    );
  }
}
