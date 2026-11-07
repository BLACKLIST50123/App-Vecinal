import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../services/ubicacion.dart';
import '../state/app_state.dart';
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
  const AuthScreen({super.key, this.mensaje});
  final String? mensaje;

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
      await context.read<AppState>().cargarPerfil();
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
    final faltante = validarNombre(_nombre.text) ??
        (id == null
            ? _errorId
            : _usarCorreo && validarTelefono(_telefono.text) != null
                ? validarTelefono(_telefono.text)
            : _clave.text.length < 6
                ? 'La clave debe tener al menos 6 números.'
                : _sector == null
                    ? 'Elige tu sector.'
                    : !_aceptaNormas
                        ? 'Para unirte, acepta las normas del barrio.'
                        : null);
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

  @override
  Widget build(BuildContext context) {
    final dentro = _gps != null && enZona(_gps!);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mi cuenta de vecino'),
          bottom: const TabBar(tabs: [Tab(text: 'Ingresar'), Tab(text: 'Crear cuenta')]),
        ),
        body: TabBarView(children: [
          ListView(padding: const EdgeInsets.all(16), children: [
            if (widget.mensaje != null) Card(child: ListTile(leading: const Icon(Icons.info_outline), title: Text(widget.mensaje!))),
            const SizedBox(height: 8),
            _campoCorreoClave(),
            _mensajeError(),
            const SizedBox(height: 20),
            FilledButton(onPressed: _cargando ? null : _ingresar, child: Text(_cargando ? 'Ingresando...' : 'Ingresar')),
          ]),
          ListView(padding: const EdgeInsets.all(16), children: [
            if (widget.mensaje != null) Card(child: ListTile(leading: const Icon(Icons.info_outline), title: Text(widget.mensaje!))),
            TextField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [soloLetras, LengthLimitingTextInputFormatter(60)],
              decoration: const InputDecoration(labelText: 'Tu nombre y apellido', prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 12),
            _campoCorreoClave(),
            if (_usarCorreo) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _telefono,
                keyboardType: TextInputType.phone,
                inputFormatters: formatoTelefono,
                decoration: const InputDecoration(labelText: 'Celular o WhatsApp (opcional)', hintText: '987654321', prefixIcon: Icon(Icons.phone)),
              ),
            ],
            const SizedBox(height: 16),
            const Text('¿En qué sector vives?', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in Zona.sectores.keys)
                ChoiceChip(label: Text(s), selected: _sector == s, onSelected: (_) => setState(() => _sector = s)),
            ]),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: Icon(
                  _gps == null ? Icons.location_searching : (dentro ? Icons.verified : Icons.location_off),
                  color: _gps == null ? null : (dentro ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
                  size: 32,
                ),
                title: Text(_gps == null
                    ? 'Verifica que vives en ${Zona.nombre}'
                    : (dentro ? 'Ubicación verificada en ${Zona.nombre}' : 'Estás fuera de la zona de ${Zona.nombre}')),
                subtitle: const Text('Usamos tu GPS una sola vez. No mostramos tu ubicación exacta a nadie.'),
                trailing: _buscando
                    ? const CircularProgressIndicator()
                    : TextButton(onPressed: _verificarGps, child: Text(_gps == null ? 'Verificar' : 'Repetir')),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _aceptaNormas,
              onChanged: (v) => setState(() => _aceptaNormas = v ?? false),
              title: const Text('Acepto las normas del barrio: respeto, nada de acusaciones ni datos de otros.'),
              subtitle: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: () => mostrarNormas(context), child: const Text('Leer las normas')),
              ),
            ),
            _mensajeError(),
            const SizedBox(height: 20),
            FilledButton(onPressed: _cargando ? null : _registrar, child: Text(_cargando ? 'Creando...' : 'Crear mi cuenta')),
          ]),
        ]),
      ),
    );
  }
}
