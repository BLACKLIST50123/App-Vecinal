import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../screens/detalles.dart';
import '../../screens/qr_screens.dart';
import '../../services/ubicacion.dart';
import '../../state/app_state.dart';
import '../../ui/widgets.dart';
import '../../util.dart';
import 'sos_navegacion.dart';
import 'sos_tipos.dart';

enum _Fase { elegir, cuenta, enviando, listo }

/// Pantalla completa en Rojo Alerta Crítica. Pensada para crisis:
/// 1 toque por reporte, 3 s para cancelar, sin sonidos (discreta),
/// textos cortos y botones grandes.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  static const _segundos = 3;

  _Fase _fase = _Fase.elegir;
  TipoSos? _tipo;
  int _cuenta = _segundos;
  Timer? _timer;
  bool? _enviadoEnLinea; // true: publicado · false: guardado sin internet
  String? _error;
  Map<String, dynamic>? _datos;

  @override
  void initState() {
    super.initState();
    sosAbierto.value = true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    sosAbierto.value = false;
    super.dispose();
  }

  void _elegir(TipoSos t) {
    HapticFeedback.mediumImpact();
    setState(() {
      _tipo = t;
      _fase = _Fase.cuenta;
      _cuenta = _segundos;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_cuenta <= 1) {
        t.cancel();
        _enviar();
      } else {
        setState(() => _cuenta--);
      }
    });
  }

  void _cancelar() {
    _timer?.cancel();
    setState(() {
      _fase = _Fase.elegir;
      _tipo = null;
    });
  }

  Future<void> _enviar() async {
    _timer?.cancel();
    final t = _tipo;
    if (t == null) return;
    final st = context.read<AppState>();
    setState(() => _fase = _Fase.enviando);
    HapticFeedback.heavyImpact();

    final punto = st.ubicacion ?? await Ubicacion.gps().timeout(const Duration(seconds: 6), onTimeout: () => null) ?? st.referencia;
    final aprox = aproximar(punto);
    final tel = st.perfil?['telefono'] as String?;
    final datos = <String, dynamic>{
      'id': nuevoId(),
      'tipo': 'pido',
      'categoria': t.categoria,
      'titulo': t.reporte,
      'descripcion': 'Reporte SOS de un toque. Contactar con cuidado.',
      'contacto_nombre': st.logueado ? st.nombre : null,
      'contacto_telefono': tel,
      'prioridad': t.prioridad,
      'es_emergencia': true,
      'lat': aprox.lat,
      'lng': aprox.lng,
      'sector': st.sector,
      'origen': 'sos',
      'autor_nombre': st.logueado ? st.nombre : 'Vecino (SOS)',
      'creado_offline_en': DateTime.now().toUtc().toIso8601String(),
      if (!st.logueado) 'autor_id': null,
    };
    try {
      final enviado = await st.publicar('publicaciones', datos);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _datos = datos;
        _enviadoEnLinea = enviado;
        _error = null;
        _fase = _Fase.listo;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is PostgrestException && e.code == 'P0001' ? e.message : traducirError(e);
        _fase = _Fase.listo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: ColoresSos.rojo,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight - 36),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _Encabezado(onCerrar: () => Navigator.maybePop(context)),
                      const SizedBox(height: 20),
                      switch (_fase) {
                        _Fase.elegir => _Cuadricula(onElegir: _elegir),
                        _Fase.cuenta => _CuentaRegresiva(tipo: _tipo!, cuenta: _cuenta, onCancelar: _cancelar, onYa: _enviar),
                        _Fase.enviando => const _Enviando(),
                        _Fase.listo => _Resultado(
                            tipo: _tipo!,
                            enLinea: _enviadoEnLinea,
                            error: _error,
                            onOtro: _cancelar,
                            onQr: _datos == null
                                ? null
                                : () => Navigator.push(context, MaterialPageRoute(builder: (_) => MostrarQrScreen(datos: _datos!))),
                          ),
                      },
                      const SizedBox(height: 16),
                      if (_fase == _Fase.elegir) const _TarjetaAtajo(),
                      const SizedBox(height: 16),
                      const _NumerosOficiales(),
                    ]),
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

// --------------------------------------------------------------- piezas

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.onCerrar});
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(
              header: true,
              child: const Text('MODO EMERGENCIA',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ),
            const SizedBox(height: 2),
            const Text('Reporte rápido y discreto',
                style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 16, fontWeight: FontWeight.w500)),
          ]),
        ),
        Material(
          color: Colors.white.withValues(alpha: 0.18),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: 'Salir del modo emergencia',
            onPressed: onCerrar,
            icon: const Icon(Icons.close, color: Colors.white),
            iconSize: 28,
          ),
        ),
      ]);
}

class _Cuadricula extends StatelessWidget {
  const _Cuadricula({required this.onElegir});
  final ValueChanged<TipoSos> onElegir;

  @override
  Widget build(BuildContext context) {
    final tipos = TipoSos.values;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Toca lo que está pasando:',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      for (var i = 0; i < tipos.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _TarjetaSos(tipo: tipos[i], onTap: () => onElegir(tipos[i]))),
              const SizedBox(width: 12),
              Expanded(child: i + 1 < tipos.length ? _TarjetaSos(tipo: tipos[i + 1], onTap: () => onElegir(tipos[i + 1])) : const SizedBox()),
            ]),
          ),
        ),
    ]);
  }
}

class _TarjetaSos extends StatelessWidget {
  const _TarjetaSos({required this.tipo, required this.onTap});
  final TipoSos tipo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '${tipo.titulo}. ${tipo.subtitulo}. Toca para reportar.',
        excludeSemantics: true,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          elevation: 2,
          shadowColor: Colors.black26,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 140),
              padding: const EdgeInsets.all(16),
              decoration: tipo.advertencia
                  ? BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: ColoresSos.ambar, width: 3))
                  : null,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: tipo.colorSuave, borderRadius: BorderRadius.circular(16)),
                  child: Icon(tipo.icono, color: tipo.color, size: 30),
                ),
                const SizedBox(height: 12),
                Text(tipo.titulo, style: const TextStyle(color: Color(0xFF1D2925), fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(tipo.subtitulo, style: TextStyle(color: tipo.advertencia ? ColoresSos.ambar : const Color(0xFF5F6B66), fontSize: 14, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
}

class _CuentaRegresiva extends StatelessWidget {
  const _CuentaRegresiva({required this.tipo, required this.cuenta, required this.onCancelar, required this.onYa});
  final TipoSos tipo;
  final int cuenta;
  final VoidCallback onCancelar, onYa;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            Icon(tipo.icono, color: tipo.color, size: 44),
            const SizedBox(height: 8),
            Text('Enviando "${tipo.titulo}"', textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1D2925))),
            const SizedBox(height: 10),
            Text('$cuenta', style: TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: tipo.color, height: 1)),
            const SizedBox(height: 6),
            const Text('Se enviará solo. Puedes cancelar si fue un error.',
                textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF5F6B66), fontSize: 15)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 56), foregroundColor: const Color(0xFF1D2925)),
                  onPressed: onCancelar,
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 56), backgroundColor: ColoresSos.rojoOscuro),
                  onPressed: onYa,
                  child: const Text('Enviar ya'),
                ),
              ),
            ]),
          ]),
        ),
      );
}

class _Enviando extends StatelessWidget {
  const _Enviando();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: const Column(children: [
          CircularProgressIndicator(color: ColoresSos.rojo, semanticsLabel: 'Enviando reporte'),
          SizedBox(height: 14),
          Text('Enviando tu reporte…', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1D2925))),
        ]),
      );
}

class _Resultado extends StatelessWidget {
  const _Resultado({required this.tipo, required this.enLinea, required this.error, required this.onOtro, this.onQr});
  final TipoSos tipo;
  final bool? enLinea;
  final String? error;
  final VoidCallback onOtro;
  final VoidCallback? onQr;

  @override
  Widget build(BuildContext context) {
    final ok = error == null;
    final (icono, titulo, texto) = !ok
        ? (Icons.error_outline, 'No se pudo enviar', error!)
        : enLinea == true
            ? (Icons.check_circle, 'Alerta enviada',
                'Tus vecinos y las organizaciones de apoyo ya ven tu reporte de "${tipo.titulo}" en el tablero de emergencia, con tu ubicación aproximada.')
            : (Icons.cloud_off, 'Guardada sin internet',
                'Se enviará apenas haya señal. Si es urgente, muestra el QR a un vecino con internet para que la envíe por ti.');
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Icon(icono, size: 52, color: ok ? const Color(0xFF2E7D32) : ColoresSos.rojo),
          const SizedBox(height: 8),
          Text(titulo, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1D2925))),
          const SizedBox(height: 8),
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Color(0xFF3B4842), height: 1.4)),
          const SizedBox(height: 16),
          if (ok && enLinea == false && onQr != null) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: ColoresSos.rojoOscuro),
              onPressed: onQr,
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Mostrar QR'),
            ),
            const SizedBox(height: 10),
          ],
          OutlinedButton(onPressed: onOtro, child: const Text('Hacer otro reporte')),
          const SizedBox(height: 10),
          TextButton(onPressed: () => Navigator.maybePop(context), child: const Text('Volver a la app')),
        ]),
      ),
    );
  }
}

class _TarjetaAtajo extends StatelessWidget {
  const _TarjetaAtajo();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.volume_up_outlined, color: Colors.white, size: 30),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Atajo con botones físicos', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text(
                'Con App Vecinal abierta, presiona 3 veces seguidas cualquier botón de volumen para abrir el SOS sin mirar la pantalla.',
                style: TextStyle(color: Color(0xF2FFFFFF), fontSize: 14, height: 1.4),
              ),
            ]),
          ),
        ]),
      );
}

class _NumerosOficiales extends StatelessWidget {
  const _NumerosOficiales();

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text(
          'Si puedes hacerlo con seguridad, llama al 105 (Policía) o al 106 (Ambulancia).',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _BotonLlamar(numero: '105', texto: 'Policía', icono: Icons.local_police_outlined)),
          const SizedBox(width: 12),
          Expanded(child: _BotonLlamar(numero: '106', texto: 'Ambulancia', icono: Icons.emergency_outlined)),
        ]),
      ]);
}

class _BotonLlamar extends StatelessWidget {
  const _BotonLlamar({required this.numero, required this.texto, required this.icono});
  final String numero, texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 56),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 2),
        ),
        onPressed: () => llamar(numero),
        icon: Icon(icono),
        label: Text('$numero · $texto'),
      );
}
