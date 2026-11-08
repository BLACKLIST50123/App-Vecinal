import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/ubicacion.dart';
import '../state/app_state.dart';
import '../ui/tema.dart';
import '../ui/widgets.dart';
import '../util.dart';

/// Llave del Navigator principal: permite abrir el SOS desde el botón
/// flotante global y desde el atajo de volumen, estés en la pantalla que estés.
final navegador = GlobalKey<NavigatorState>();

/// true mientras la pantalla SOS está abierta (oculta el botón flotante).
final sosAbierto = ValueNotifier<bool>(false);

Future<void> abrirSOS() async {
  final nav = navegador.currentState;
  if (nav == null || sosAbierto.value) return;
  sosAbierto.value = true;
  HapticFeedback.heavyImpact();
  await nav.push(PageRouteBuilder<void>(
    fullscreenDialog: true,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => const ModoEmergenciaScreen(),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
  ));
  sosAbierto.value = false;
}

// ============================================================ atajo volumen

/// Atajo ciego: presionar cualquier botón de volumen 3 veces seguidas (en
/// menos de 2 segundos) abre el SOS. No bloquea el cambio de volumen.
class AtajoVolumen {
  static final _toques = <DateTime>[];
  static bool _instalado = false;

  static void instalar() {
    if (_instalado) return;
    _instalado = true;
    HardwareKeyboard.instance.addHandler(_alTecla);
  }

  static bool _alTecla(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    final k = e.logicalKey;
    if (k != LogicalKeyboardKey.audioVolumeUp && k != LogicalKeyboardKey.audioVolumeDown) return false;
    final ahora = DateTime.now();
    _toques
      ..add(ahora)
      ..removeWhere((t) => ahora.difference(t) > const Duration(seconds: 2));
    if (_toques.length >= 3) {
      _toques.clear();
      abrirSOS();
    }
    return false;
  }
}

// ============================================================ modo emergencia

class _OpcionSOS {
  const _OpcionSOS(this.categoria, this.icono, this.colorIcono, this.titulo, this.detalle, {this.destacada = false});
  final String categoria;
  final IconData icono;
  final Color colorIcono;
  final String titulo;
  final String detalle;
  final bool destacada;
}

const _opciones = [
  _OpcionSOS('sos_medico', Icons.medical_services, Color(0xFFEF6C00), 'Auxilio Médico', 'Necesito atención'),
  _OpcionSOS('sos_inseguridad', Icons.campaign, Paleta.rojo, 'Inseguridad', 'Riesgo o amenaza'),
  _OpcionSOS('sos_agua', Icons.water_drop, Color(0xFF29B6F6), 'Falta de Agua', 'Corte no informado'),
  _OpcionSOS('sos_sismo', Icons.house, Color(0xFF6D4C41), 'Sismo', 'Reportar daños', destacada: true),
];

/// Pantalla completa en Rojo Alerta Crítica (#E53935): "MODO EMERGENCIA".
class ModoEmergenciaScreen extends StatefulWidget {
  const ModoEmergenciaScreen({super.key});

  @override
  State<ModoEmergenciaScreen> createState() => _ModoEmergenciaScreenState();
}

class _ModoEmergenciaScreenState extends State<ModoEmergenciaScreen> {
  String? _enviando; // categoría que se está enviando
  _OpcionSOS? _enviado;
  bool _enCola = false;

  Future<void> _reportar(_OpcionSOS o) async {
    if (_enviando != null) return;
    HapticFeedback.mediumImpact();
    setState(() => _enviando = o.categoria);
    final st = context.read<AppState>();
    final gps = await Ubicacion.gps().timeout(const Duration(seconds: 8), onTimeout: () => null);
    final punto = gps != null && enZona(gps) ? gps : st.referencia;
    final aprox = aproximar(punto);
    final datos = <String, dynamic>{
      'id': nuevoId(),
      'tipo': 'pido',
      'categoria': o.categoria,
      'titulo': 'SOS: ${o.titulo}',
      'descripcion': '${o.detalle}. Reporte rápido desde el botón SOS${gps == null ? ' (ubicación aproximada por sector)' : ''}.',
      'contacto_nombre': st.logueado ? st.nombre : null,
      'personas': 1,
      'prioridad': 'critica',
      'es_emergencia': true,
      'lat': aprox.lat,
      'lng': aprox.lng,
      'sector': st.sector,
      'autor_nombre': st.logueado ? st.nombre : 'Vecino (SOS)',
      'creado_offline_en': DateTime.now().toUtc().toIso8601String(),
      if (!st.logueado) ...{'autor_id': null, 'origen': 'sin_cuenta'},
    };
    var enviado = false;
    try {
      enviado = await st.publicar('publicaciones', datos);
    } catch (_) {
      enviado = false;
    }
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _enviando = null;
      _enviado = o;
      _enCola = !enviado;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Paleta.rojo,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _enviado == null ? _opcionesVista() : _confirmacion(),
          ),
        ),
      ),
    );
  }

  Widget _encabezado() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(20)),
            child: const Text('MODO EMERGENCIA',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: 'Cerrar modo emergencia',
            excludeSemantics: true,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.pop(context),
                child: const SizedBox(width: 48, height: 48, child: Icon(Icons.close, color: Paleta.tinta)),
              ),
            ),
          ),
        ]),
      );

  Widget _opcionesVista() => ListView(key: const ValueKey('opciones'), children: [
        _encabezado(),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 26, 20, 0),
          child: Text('Reporte rápido y discreto',
              style: TextStyle(color: Color(0xFFFFE0DC), fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Semantics(
            header: true,
            child: const Text('¿Qué está pasando?',
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.1)),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 10, 40, 0),
          child: Text('Toca una opción. Enviaremos tu ubicación a la brigada vecinal.',
              style: TextStyle(color: Colors.white, fontSize: 16, height: 1.4)),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            for (var i = 0; i < _opciones.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: _tarjeta(_opciones[i])),
                    const SizedBox(width: 12),
                    Expanded(child: _tarjeta(_opciones[i + 1])),
                  ]),
                ),
              ),
          ]),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFC62828), borderRadius: BorderRadius.circular(18)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.volume_up, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Atajo con botones físicos', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                SizedBox(height: 3),
                Text('Presiona cualquier botón de volumen 3 veces para activar el SOS de forma ciega y discreta.',
                    style: TextStyle(color: Colors.white, fontSize: 14, height: 1.35)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            const Text('Si puedes hacerlo con seguridad, llama al 105 o al 106.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _numero('105', 'Policía'),
              const SizedBox(width: 10),
              _numero('106', 'SAMU'),
            ]),
          ]),
        ),
        const SizedBox(height: 24),
      ]);

  Widget _numero(String n, String quien) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 44),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
        ),
        onPressed: () => llamar(n),
        icon: const Icon(Icons.call, size: 18),
        label: Text('$quien $n', style: const TextStyle(fontSize: 14)),
      );

  Widget _tarjeta(_OpcionSOS o) {
    final cargando = _enviando == o.categoria;
    final fondo = o.destacada ? const Color(0xFFFFA726) : Colors.white;
    return Semantics(
      button: true,
      label: '${o.titulo}. ${o.detalle}. Envía una alerta a la brigada vecinal.',
      excludeSemantics: true,
      child: Material(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _enviando == null ? () => _reportar(o) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 120),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                cargando
                    ? const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: Paleta.rojo))
                    : Icon(o.icono, color: o.colorIcono, size: 34),
                const SizedBox(height: 18),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cargando ? 'Enviando...' : o.titulo,
                      style: const TextStyle(color: Color(0xFF5D1A14), fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(o.detalle, style: const TextStyle(color: Color(0xFF7A3A33), fontSize: 13)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _confirmacion() {
    final o = _enviado!;
    return ListView(key: const ValueKey('confirmacion'), children: [
      _encabezado(),
      const SizedBox(height: 40),
      Center(
        child: Container(
          width: 96,
          height: 96,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Icon(_enCola ? Icons.schedule_send : Icons.check_rounded, color: Paleta.rojo, size: 56),
        ),
      ),
      const SizedBox(height: 22),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(_enCola ? 'Alerta guardada' : 'Alerta enviada',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Text(
          _enCola
              ? 'No hay internet ahora. Tu alerta de "${o.titulo}" se enviará sola apenas haya señal.'
              : 'La brigada vecinal recibió tu alerta de "${o.titulo}" con tu ubicación aproximada.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
        ),
      ),
      const SizedBox(height: 32),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final (nombre, numero, icono) in numerosEmergencia)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Paleta.rojo),
                onPressed: () => llamar(numero),
                icon: Icon(icono),
                label: Text('Llamar a $nombre ($numero)'),
              ),
            ),
          const SizedBox(height: 6),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 2),
            ),
            onPressed: () => setState(() => _enviado = null),
            child: const Text('Reportar otra cosa'),
          ),
        ]),
      ),
      const SizedBox(height: 24),
    ]);
  }
}
