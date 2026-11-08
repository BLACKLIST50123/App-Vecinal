import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../services/ubicacion.dart';
import '../state/app_state.dart';
import '../ui/tema.dart';
import '../util.dart';
import 'confianza.dart';

String _errorAuth(Object e) {
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'Número/correo o clave incorrectos.';
    if (m.contains('already registered')) return 'Ese número o correo ya tiene una cuenta. Usa "Ingresar".';
    if (m.contains('not confirmed')) {
      return 'La cuenta espera confirmación. El administrador debe desactivar "Confirm email" en Supabase.';
    }
    if (m.contains('password')) return 'La clave debe tener al menos 6 números o letras.';
    if (m.contains('email')) return 'Revisa que el número o correo esté bien escrito.';
    return e.message;
  }
  return 'Sin conexión. Necesitas internet para crear tu cuenta o ingresar.';
}

/// Muchos vecinos no usan correo: la cuenta se crea con el celular.
/// Internamente se convierte en un identificador tipo correo, solo para
/// Supabase Auth (dominio reservado example.com; nunca se envían correos).
String? _identificador(String entrada, {required bool usarCorreo}) {
  final t = entrada.trim();
  if (usarCorreo) return t.contains('@') ? t.toLowerCase() : null;
  final d = soloDigitos(t);
  final cel = d.length == 11 && d.startsWith('51') ? d.substring(2) : d;
  if (cel.length != 9 || !cel.startsWith('9')) return null;
  return '51$cel@vecinos.example.com';
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.mensaje, this.tabInicial = 0});
  final String? mensaje;

  /// 0 = Ingresar, 1 = Crear cuenta.
  final int tabInicial;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  String? _sector;
  Punto? _gps;
  bool _buscando = false;
  bool _cargando = false;
  bool _verClave = false;
  bool _usarCorreo = false;
  bool _aceptaNormas = false;
  String? _error;

  /// Registro en 2 pasos: 0 = tus datos (nombre, celular, clave),
  /// 1 = tu barrio (GPS, sector y normas). Menos campos por pantalla.
  int _paso = 0;
  bool _sectorSugerido = false; // el sector lo propuso el GPS

  @override
  void dispose() {
    for (final c in [_correo, _clave, _nombre, _telefono]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _faltaPaso1() =>
      validarNombre(_nombre.text) ??
      (_id == null
          ? _errorId
          : _usarCorreo && validarTelefono(_telefono.text) != null
              ? validarTelefono(_telefono.text)
              : _clave.text.length < 6
                  ? (_usarCorreo ? 'La contraseña debe tener al menos 6 caracteres.' : 'La clave debe tener al menos 6 números.')
                  : null);

  void _siguiente() {
    final falta = _faltaPaso1();
    if (falta != null) {
      setState(() => _error = falta);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _paso = 1;
    });
    if (_gps == null && !_buscando) _verificarGps();
  }

  String? get _id => _identificador(_correo.text, usarCorreo: _usarCorreo);
  String get _errorId => _usarCorreo
      ? 'Escribe un correo válido.'
      : 'Escribe tu número de celular de 9 dígitos (empieza con 9).';

  Future<void> _verificarGps() async {
    setState(() => _buscando = true);
    final p = await Ubicacion.gps();
    if (!mounted) return;
    setState(() {
      _gps = p;
      _buscando = false;
      // Un toque menos: si el GPS te ubica en la zona, proponemos tu sector.
      if (p != null && enZona(p) && (_sector == null || _sectorSugerido)) {
        _sector = sectorMasCercano(p);
        _sectorSugerido = true;
      }
    });
  }

  Future<void> _ingresar() async {
    final id = _id;
    if (id == null) {
      setState(() => _error = _errorId);
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: id, password: _clave.text);
      if (!mounted) return;
      final st = context.read<AppState>();
      await st.cargarPerfil();
      // Cuenta que ya existía: sin tutorial ni "¿Quién soy hoy?".
      st.entrarConCuentaExistente();
      avisar('¡Bienvenido de nuevo!');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = _errorAuth(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _registrar() async {
    final id = _id;
    final falta1 = _faltaPaso1();
    if (falta1 != null) {
      setState(() {
        _paso = 0;
        _error = falta1;
      });
      return;
    }
    final faltante = _sector == null
        ? 'Elige tu sector.'
        : !_aceptaNormas
            ? 'Para unirte, acepta las normas del barrio.'
            : null;
    if (faltante != null) {
      setState(() => _error = faltante);
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final telefono = _usarCorreo ? _telefono.text.trim() : soloDigitos(_correo.text).replaceFirst(RegExp(r'^51(?=9\d{8}$)'), '');
      final r = await Supabase.instance.client.auth.signUp(
        email: id!,
        password: _clave.text,
        data: {
          'nombre': _nombre.text.trim(),
          'telefono': telefono,
          'sector': _sector,
          if (_gps != null) 'lat': _gps!.lat,
          if (_gps != null) 'lng': _gps!.lng,
        },
      );
      if (!mounted) return;
      if (r.session == null) {
        setState(() => _error = _usarCorreo
            ? 'Te enviamos un correo para confirmar tu cuenta. Ábrelo y luego ingresa.'
            : 'La cuenta quedó esperando confirmación. El administrador debe desactivar "Confirm email" en Supabase.');
        return;
      }
      await context.read<AppState>().cargarPerfil();
      avisar(_gps != null && enZona(_gps!)
          ? '¡Cuenta creada! Eres vecino verificado de ${Zona.nombre}.'
          : '¡Cuenta creada! Quedó sin la insignia de vecino verificado porque no confirmamos tu GPS en ${Zona.nombre}.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = _errorAuth(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Widget _campoCorreoClave() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('¿Con qué quieres entrar?', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, icon: Icon(Icons.phone_android), label: Text('Celular')),
            ButtonSegment(value: true, icon: Icon(Icons.email), label: Text('Correo')),
          ],
          selected: {_usarCorreo},
          onSelectionChanged: (s) => setState(() {
            _usarCorreo = s.first;
            _correo.clear();
            _error = null;
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          key: ValueKey(_usarCorreo),
          controller: _correo,
          keyboardType: _usarCorreo ? TextInputType.emailAddress : TextInputType.phone,
          inputFormatters: _usarCorreo ? null : formatoTelefono,
          autofillHints: [_usarCorreo ? AutofillHints.email : AutofillHints.telephoneNumberNational],
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            labelText: _usarCorreo ? 'Correo' : 'Número de celular',
            hintText: _usarCorreo ? 'nombre@correo.com' : '9XX XXX XXX',
            prefixIcon: Icon(_usarCorreo ? Icons.email : Icons.phone_android),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _clave,
          obscureText: !_verClave,
          keyboardType: _usarCorreo ? TextInputType.visiblePassword : TextInputType.number,
          autofillHints: const [AutofillHints.password],
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            labelText: _usarCorreo ? 'Contraseña (mínimo 6)' : 'Clave de 6 números',
            helperText: 'Anótala en un lugar seguro',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              tooltip: _verClave ? 'Ocultar contraseña' : 'Mostrar contraseña',
              icon: Icon(_verClave ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _verClave = !_verClave),
            ),
          ),
        ),
      ]);

  Widget _mensajeError() => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        );

  /// Un solo formulario a la vez: Ingresar o Crear cuenta. Se cambia con
  /// el enlace de abajo (sin pestañas que confundan).
  late bool _registro = widget.tabInicial == 1;

  void _cambiarModo() {
    FocusScope.of(context).unfocus();
    setState(() {
      _registro = !_registro;
      _paso = 0;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dentro = _gps != null && enZona(_gps!);
    return Scaffold(
      appBar: AppBar(title: Text(_registro ? 'Crear cuenta' : 'Iniciar sesión')),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a),
              child: child,
            ),
          ),
          // Abajo, espacio extra para que el botón SOS flotante no tape los botones.
          child: _registro
              ? ListView(key: const ValueKey('registro'), padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), children: [
                  if (widget.mensaje != null) ...[_aviso(), const SizedBox(height: 12)],
                  _IndicadorPasos(paso: _paso),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    ),
                    child: _paso == 0 ? _pasoDatos() : _pasoBarrio(dentro),
                  ),
                  if (_paso == 0) ...[
                    const SizedBox(height: 20),
                    _EnlaceCambio(pregunta: '¿Ya tienes cuenta?', accion: 'Iniciar sesión', onTap: _cambiarModo),
                  ],
                ])
              : ListView(key: const ValueKey('ingresar'), padding: const EdgeInsets.fromLTRB(16, 24, 16, 120), children: [
                  Center(child: Image.asset('assets/images/logo_icono.png', width: 72, semanticLabel: 'Logo de Conecta Vecino')),
                  const SizedBox(height: 16),
                  const _TituloPaso(titulo: '¡Hola de nuevo!', texto: 'Entra con tu celular y tu clave de 6 números.'),
                  const SizedBox(height: 16),
                  if (widget.mensaje != null) ...[_aviso(), const SizedBox(height: 16)],
                  _campoCorreoClave(),
                  _mensajeError(),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 58,
                    child: FilledButton.icon(
                      onPressed: _cargando ? null : _ingresar,
                      icon: _cargando
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                          : const Icon(Icons.login),
                      label: Text(_cargando ? 'Ingresando...' : 'Ingresar', style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _EnlaceCambio(pregunta: '¿Primera vez aquí?', accion: 'Crear cuenta gratis', onTap: _cambiarModo, destacado: true),
                ]),
        ),
      ),
    );
  }

  Widget _aviso() => Card(
        margin: EdgeInsets.zero,
        child: ListTile(leading: const Icon(Icons.info_outline), title: Text(widget.mensaje!)),
      );

  // ------------------------------------------------ paso 1: tus datos

  Widget _pasoDatos() => Column(key: const ValueKey('paso-datos'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const _TituloPaso(titulo: '¿Cómo te llamas?', texto: 'Así te verán tus vecinos cuando publiques o ayudes.'),
        const SizedBox(height: 14),
        TextField(
          controller: _nombre,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          inputFormatters: [soloLetras, LengthLimitingTextInputFormatter(60)],
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(labelText: 'Tu nombre', hintText: 'Ej. Rosa Huamán', prefixIcon: Icon(Icons.person)),
        ),
        const SizedBox(height: 20),
        _campoCorreoClave(),
        if (_usarCorreo) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            inputFormatters: formatoTelefono,
            decoration: const InputDecoration(
                labelText: 'Celular o WhatsApp (opcional)', hintText: '987654321', prefixIcon: Icon(Icons.phone)),
          ),
        ],
        _mensajeError(),
        const SizedBox(height: 24),
        SizedBox(
          height: 58,
          child: FilledButton.icon(
            onPressed: _siguiente,
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Siguiente', style: TextStyle(fontSize: 18)),
          ),
        ),
      ]);

  // ------------------------------------------------ paso 2: tu barrio

  Widget _pasoBarrio(bool dentro) {
    final verde = Paleta.verde;
    final (icono, color, titulo) = _buscando
        ? (Icons.location_searching, Paleta.gris, 'Buscando tu ubicación...')
        : _gps == null
            ? (Icons.location_searching, Paleta.gris, 'Verifica que vives en ${Zona.nombre}')
            : dentro
                ? (Icons.verified, verde, 'Eres vecino verificado de ${Zona.nombre}')
                : (Icons.location_off, Paleta.rojo, 'Estás fuera de la zona de ${Zona.nombre}');
    return Column(key: const ValueKey('paso-barrio'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _TituloPaso(
        titulo: 'Hola, ${_nombre.text.trim().split(' ').first}. ¿Dónde vives?',
        texto: 'Así te mostramos lo que está cerca de tu casa.',
      ),
      const SizedBox(height: 16),
      // Verificación GPS (D2): se intenta sola al llegar a este paso.
      AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: _buscando
                ? Padding(padding: const EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 3, color: color))
                : Icon(icono, color: color, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(
                liveRegion: true,
                child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              const SizedBox(height: 2),
              Text('Usamos tu GPS una sola vez. No mostramos tu ubicación exacta a nadie.',
                  style: TextStyle(color: Paleta.gris, fontSize: 13, height: 1.3)),
            ]),
          ),
          if (!_buscando && !dentro)
            TextButton(onPressed: _verificarGps, child: Text(_gps == null ? 'Verificar' : 'Reintentar')),
        ]),
      ),
      const SizedBox(height: 22),
      Row(children: [
        const Expanded(child: Text('Tu sector', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        if (_sectorSugerido && _sector != null)
          Row(children: [
            Icon(Icons.auto_awesome, size: 16, color: Paleta.acentoOscuro),
            SizedBox(width: 4),
            Text('Sugerido por tu GPS', style: TextStyle(color: Paleta.acentoOscuro, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final s in Zona.sectores.keys)
          ChoiceChip(
            label: Text(s),
            selected: _sector == s,
            onSelected: (_) => setState(() {
              _sector = s;
              _sectorSugerido = false;
              _error = null;
            }),
          ),
      ]),
      const SizedBox(height: 18),
      Material(
        color: _aceptaNormas ? Paleta.primarioSuave : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: CheckboxListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          value: _aceptaNormas,
          onChanged: (v) => setState(() {
            _aceptaNormas = v ?? false;
            _error = null;
          }),
          title: const Text('Acepto las normas del barrio: respeto, nada de acusaciones ni datos de otros.'),
          subtitle: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () => mostrarNormas(context), child: const Text('Leer las normas')),
          ),
        ),
      ),
      _mensajeError(),
      const SizedBox(height: 24),
      Row(children: [
        SizedBox(
          height: 58,
          child: OutlinedButton.icon(
            onPressed: _cargando ? null : () => setState(() {
              _paso = 0;
              _error = null;
            }),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Atrás'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 58,
            child: FilledButton.icon(
              onPressed: _cargando ? null : _registrar,
              icon: _cargando
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(_cargando ? 'Creando...' : 'Crear mi cuenta', style: const TextStyle(fontSize: 18)),
            ),
          ),
        ),
      ]),
    ]);
  }
}

/// "Paso 1 de 2": dos barras y el nombre del paso actual.
class _IndicadorPasos extends StatelessWidget {
  const _IndicadorPasos({required this.paso});
  final int paso;

  static const _nombres = ['Tus datos', 'Tu barrio'];

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Paso ${paso + 1} de 2: ${_nombres[paso]}',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('PASO ${paso + 1} DE 2 · ${_nombres[paso].toUpperCase()}',
            style: TextStyle(color: Paleta.acentoOscuro, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
        const SizedBox(height: 8),
        Row(children: [
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 6,
                decoration: BoxDecoration(
                  color: i <= paso ? color : Paleta.linea,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _TituloPaso extends StatelessWidget {
  const _TituloPaso({required this.titulo, required this.texto});
  final String titulo, texto;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          header: true,
          child: Text(titulo, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.15)),
        ),
        const SizedBox(height: 6),
        Text(texto, style: TextStyle(color: Paleta.gris, fontSize: 15, height: 1.35)),
      ]);
}

/// "¿Primera vez aquí? Crear cuenta gratis" / "¿Ya tienes cuenta? Iniciar sesión".
class _EnlaceCambio extends StatelessWidget {
  const _EnlaceCambio({required this.pregunta, required this.accion, required this.onTap, this.destacado = false});
  final String pregunta, accion;
  final VoidCallback onTap;
  final bool destacado;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Divider(color: Paleta.linea)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(pregunta, style: TextStyle(color: Paleta.gris, fontSize: 15)),
          ),
          Expanded(child: Divider(color: Paleta.linea)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: destacado ? 56 : 48,
          child: destacado
              ? OutlinedButton.icon(
                  onPressed: onTap,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Paleta.superficie,
                    side: BorderSide(color: Paleta.primario, width: 1.5),
                  ),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text(accion, style: const TextStyle(fontSize: 17)),
                )
              : TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.login),
                  label: Text(accion, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ),
        ),
      ]);
}
