import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/app_state.dart';
import '../ui/tema.dart';
import '../util.dart';
import 'auth_screen.dart';
import 'confianza.dart';
import 'detalles.dart';

/// Muestra el código de recuperación para que el vecino lo guarde.
/// No se puede cerrar sin confirmar que lo anotó.
Future<void> mostrarCodigoRecuperacion(BuildContext context, String codigo, {String? titulo}) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.key_rounded, size: 40, color: Paleta.acentoOscuro),
        title: Text(titulo ?? 'Tu código para recuperar tu clave', textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Si un día olvidas tu clave, con este código pones una nueva en segundos.', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Paleta.oroFondo,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Paleta.oroClaro, width: 2),
            ),
            child: SelectableText(
              codigo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 4, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Anótalo en un papel o tómale una captura. Sirve una sola vez.',
              textAlign: TextAlign.center, style: TextStyle(color: Paleta.gris)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: codigo));
                  avisar('Código copiado');
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copiar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => compartirWhatsapp('Mi código para recuperar mi clave de Conecta Vecino: $codigo'),
                icon: const Icon(Icons.share),
                label: const Text('Guardar'),
              ),
            ),
          ]),
        ]),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(c),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            child: const Text('Ya lo guardé'),
          ),
        ],
      ),
    );

/// "¿Olvidaste tu clave?": celular + código + clave nueva.
/// Con correo, también se puede pedir un enlace al correo.
class RecuperarClaveScreen extends StatefulWidget {
  const RecuperarClaveScreen({super.key, this.celular = '', this.usarCorreo = false});
  final String celular;
  final bool usarCorreo;

  @override
  State<RecuperarClaveScreen> createState() => _RecuperarClaveScreenState();
}

class _RecuperarClaveScreenState extends State<RecuperarClaveScreen> {
  late final _cuenta = TextEditingController(text: widget.celular);
  final _codigo = TextEditingController();
  final _nueva = TextEditingController();
  final _nueva2 = TextEditingController();
  late bool _usarCorreo = widget.usarCorreo;
  bool _ver = false;
  bool _cargando = false;
  String? _errCuenta, _errCodigo, _errNueva, _errNueva2, _error;

  @override
  void dispose() {
    for (final c in [_cuenta, _codigo, _nueva, _nueva2]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _celular => soloDigitos(_cuenta.text).replaceFirst(RegExp(r'^51(?=9\d{8}$)'), '');

  Future<void> _cambiar() async {
    final codigo = _codigo.text.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    setState(() {
      _errCuenta = _usarCorreo ? validarCorreo(_cuenta.text) : validarTelefono(_celular, obligatorio: true);
      _errCodigo = codigo.length != 8 ? 'El código tiene 8 letras y números (ej. K7PM-3QXD)' : null;
      _errNueva = validarClave(_nueva.text, conCorreo: _usarCorreo, celular: _usarCorreo ? null : _celular);
      _errNueva2 = _nueva2.text != _nueva.text ? 'Las dos claves no son iguales' : null;
      _error = null;
    });
    if ([_errCuenta, _errCodigo, _errNueva, _errNueva2].any((e) => e != null)) return;
    final email = identificadorCuenta(_usarCorreo ? _cuenta.text : _celular, usarCorreo: _usarCorreo)!;
    final st = context.read<AppState>();
    setState(() => _cargando = true);
    try {
      final nuevoCodigo = await st.repo.recuperarClave(email: email, codigo: codigo, nueva: _nueva.text);
      // Entra de una vez con la clave nueva.
      await Supabase.instance.client.auth.signInWithPassword(email: email, password: _nueva.text);
      await st.cargarPerfil();
      st.entrarConCuentaExistente();
      if (!mounted) return;
      await mostrarCodigoRecuperacion(context, nuevoCodigo, titulo: '¡Listo! Guarda tu código nuevo');
      if (!mounted) return;
      avisar('Tu clave cambió. ¡Bienvenido de nuevo!');
      Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      setState(() => _error = e is SinPermiso ? e.mensaje : traducirError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _enlaceCorreo() async {
    final e = validarCorreo(_cuenta.text);
    if (e != null) return setState(() => _errCuenta = e);
    setState(() => _cargando = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(_cuenta.text.trim().toLowerCase());
      avisar('Te enviamos un enlace a tu correo para crear una contraseña nueva.');
    } catch (_) {
      setState(() => _error = 'No se pudo enviar el correo. Revisa tu internet o usa tu código.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Recuperar mi clave')),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
            const Text('Pon una clave nueva con tu código',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            const SizedBox(height: 6),
            const Text('Es el código de 8 letras y números que te dimos al crear tu cuenta.',
                style: TextStyle(color: Paleta.gris, fontSize: 15)),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, icon: Icon(Icons.phone_android), label: Text('Celular')),
                ButtonSegment(value: true, icon: Icon(Icons.email), label: Text('Correo')),
              ],
              selected: {_usarCorreo},
              onSelectionChanged: (s) => setState(() {
                _usarCorreo = s.first;
                _cuenta.clear();
                _errCuenta = null;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              key: ValueKey(_usarCorreo),
              controller: _cuenta,
              keyboardType: _usarCorreo ? TextInputType.emailAddress : TextInputType.phone,
              inputFormatters: _usarCorreo ? null : formatoTelefono,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: _usarCorreo ? 'Tu correo' : 'Tu número de celular',
                prefixIcon: Icon(_usarCorreo ? Icons.email : Icons.phone_android),
                errorText: _errCuenta,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codigo,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                LengthLimitingTextInputFormatter(9),
              ],
              style: const TextStyle(fontSize: 20, letterSpacing: 3, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                labelText: 'Código de recuperación',
                hintText: 'K7PM-3QXD',
                prefixIcon: const Icon(Icons.key_rounded),
                errorText: _errCodigo,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nueva,
              obscureText: !_ver,
              keyboardType: _usarCorreo ? TextInputType.visiblePassword : TextInputType.number,
              inputFormatters: _usarCorreo ? null : [soloNumeros, LengthLimitingTextInputFormatter(6)],
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: _usarCorreo ? 'Contraseña nueva (8 o más, letras y números)' : 'Clave nueva de 6 números',
                prefixIcon: const Icon(Icons.lock),
                errorText: _errNueva,
                suffixIcon: IconButton(
                  tooltip: _ver ? 'Ocultar' : 'Mostrar',
                  icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _ver = !_ver),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nueva2,
              obscureText: !_ver,
              keyboardType: _usarCorreo ? TextInputType.visiblePassword : TextInputType.number,
              inputFormatters: _usarCorreo ? null : [soloNumeros, LengthLimitingTextInputFormatter(6)],
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Repite la clave nueva',
                prefixIcon: const Icon(Icons.lock_outline),
                errorText: _errNueva2,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(_error!, style: const TextStyle(color: Paleta.rojoTexto, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              height: 58,
              child: FilledButton.icon(
                onPressed: _cargando ? null : _cambiar,
                icon: _cargando
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                    : const Icon(Icons.lock_reset),
                label: Text(_cargando ? 'Cambiando...' : 'Cambiar mi clave', style: const TextStyle(fontSize: 18)),
              ),
            ),
            if (_usarCorreo) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _cargando ? null : _enlaceCorreo,
                icon: const Icon(Icons.mark_email_read_outlined),
                label: const Text('No tengo código: enviarme un enlace al correo'),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Paleta.azulSuave, borderRadius: BorderRadius.circular(16)),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.support_agent, color: Paleta.azulInfo),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '¿Perdiste tu código? Acércate a la junta vecinal de tu sector con tu DNI: '
                    'ellos te dan un código nuevo en un minuto.',
                    style: TextStyle(fontSize: 15, height: 1.35),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      );
}
