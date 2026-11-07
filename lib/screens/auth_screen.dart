import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../services/ubicacion.dart';
import '../state/app_state.dart';
import '../util.dart';

String _errorAuth(Object e) {
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'Correo o contraseña incorrectos.';
    if (m.contains('already registered')) return 'Ese correo ya tiene una cuenta. Ingresa con él.';
    if (m.contains('password')) return 'La contraseña debe tener al menos 6 caracteres.';
    if (m.contains('email')) return 'Revisa que el correo esté bien escrito.';
    return e.message;
  }
  return 'Sin conexión. Necesitas internet para crear tu cuenta o ingresar.';
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
  String? _error;

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
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: _correo.text.trim(), password: _clave.text);
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
    if (_nombre.text.trim().length < 2 || _sector == null) {
      setState(() => _error = _nombre.text.trim().length < 2 ? 'Escribe tu nombre.' : 'Elige tu sector.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await Supabase.instance.client.auth.signUp(
        email: _correo.text.trim(),
        password: _clave.text,
        data: {
          'nombre': _nombre.text.trim(),
          'telefono': _telefono.text.trim(),
          'sector': _sector,
          if (_gps != null) 'lat': _gps!.lat,
          if (_gps != null) 'lng': _gps!.lng,
        },
      );
      if (!mounted) return;
      if (r.session == null) {
        setState(() => _error = 'Te enviamos un correo para confirmar tu cuenta. Ábrelo y luego ingresa.');
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

  Widget _campoCorreoClave() => Column(children: [
        TextField(
          controller: _correo,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.email)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _clave,
          obscureText: !_verClave,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Contraseña (mínimo 6)',
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
              decoration: const InputDecoration(labelText: 'Tu nombre', prefixIcon: Icon(Icons.person)),
            ),
            const SizedBox(height: 12),
            _campoCorreoClave(),
            const SizedBox(height: 12),
            TextField(
              controller: _telefono,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono o WhatsApp (opcional)', prefixIcon: Icon(Icons.phone)),
            ),
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
            _mensajeError(),
            const SizedBox(height: 20),
            FilledButton(onPressed: _cargando ? null : _registrar, child: Text(_cargando ? 'Creando...' : 'Crear mi cuenta')),
          ]),
        ]),
      ),
    );
  }
}
