import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../data/repo.dart';
import '../models.dart';
import '../services/ubicacion.dart';

final mensajero = GlobalKey<ScaffoldMessengerState>();

void avisar(String texto) {
  mensajero.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto), duration: const Duration(seconds: 5)));
}

/// Estado global: sesión, rol, modo emergencia, conexión y accesibilidad.
class AppState extends ChangeNotifier {
  AppState(this.prefs, this.repo) {
    escala = prefs.getDouble('escala') ?? 1.0;
    altoContraste = prefs.getBool('alto_contraste') ?? false;
    voz = prefs.getBool('voz') ?? true;
    tutorialVisto = prefs.getBool('tutorial_visto') ?? false;
    rolSimulado = prefs.getString('rol_simulado') ?? 'vecino';
    // El rol se elige una sola vez; después se cambia desde Perfil.
    rolElegido = prefs.getBool('rol_elegido') ?? false;
    invitado = prefs.getBool('modo_invitado') ?? false;
    especialidad = prefs.getString('especialidad');
    repo.forzarOffline = prefs.getBool('forzar_offline') ?? false;
    final p = prefs.getString('perfil');
    if (p != null) perfil = Map<String, dynamic>.from(jsonDecode(p) as Map);
    _iniciar();
  }

  final SharedPreferences prefs;
  final Repo repo;

  late double escala;
  late bool altoContraste;
  late bool voz;
  late bool tutorialVisto;

  /// Rol elegido en "¿Quién soy hoy?": 'vecino', 'prestador' o 'brigadista'.
  /// Se pregunta solo la primera vez (no en cada apertura: en una
  /// emergencia cada paso extra cuesta). Se cambia desde Perfil.
  late String rolSimulado;
  String? especialidad; // oficio del prestador (gasfitero, electricista...)
  late bool rolElegido;

  /// Entró sin cuenta desde la pantalla de bienvenida.
  late bool invitado;

  /// Ya pasó la bienvenida: con cuenta o como invitado.
  bool get entro => logueado || invitado;

  bool _red = true;
  EstadoEmergencia emergencia = const EstadoEmergencia.inactiva();
  Map<String, dynamic>? perfil;
  Punto? ubicacion;
  int version = 0;

  StreamSubscription<List<ConnectivityResult>>? _subRed;
  StreamSubscription<dynamic>? _subAuth;
  Timer? _timer;
  Timer? _debounce;
  RealtimeChannel? _canal;

  bool get online => _red && !repo.forzarOffline;
  bool get simulandoOffline => repo.forzarOffline;
  bool get logueado => repo.db.auth.currentSession != null;
  String get rol => logueado ? (perfil?['rol'] as String? ?? 'vecino') : 'visitante';
  bool get esModerador => rol == 'moderador';
  bool get esOrganizacion => rol == 'organizacion';
  bool get verificado => perfil?['verificado_gps'] == true;
  bool get modoEmergencia => emergencia.activa;
  int get pendientes => repo.pendientes.length;
  String get nombre => perfil?['nombre'] as String? ?? 'vecino';
  String? get sector => perfil?['sector'] as String?;
  String? get uid => repo.uid;

  /// Punto de referencia para "cerca de ti": GPS, o el sector, o el centro.
  Punto get referencia => ubicacion ?? Zona.sectores[sector] ?? Zona.centro;

  Future<void> _iniciar() async {
    try {
      final r = await Connectivity().checkConnectivity();
      _red = r.any((x) => x != ConnectivityResult.none);
    } catch (_) {}
    _subRed = Connectivity().onConnectivityChanged.listen(
          (r) => _cambioRed(r.any((x) => x != ConnectivityResult.none)),
        );
    _subAuth = repo.db.auth.onAuthStateChange.listen((_) => cargarPerfil());
    _escucharTiempoReal();
    unawaited(cargarPerfil());
    unawaited(actualizarEmergencia());
    unawaited(sincronizar(silencioso: true));
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => actualizarEmergencia());
  }

  /// Supabase Realtime: cuando el moderador activa la emergencia o alguien
  /// publica un pedido, todos los celulares se actualizan al instante.
  void _escucharTiempoReal() {
    try {
      _canal = repo.db
          .channel('barrio')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'emergencia',
            callback: (_) async {
              final antes = emergencia.activa;
              await actualizarEmergencia();
              if (!antes && emergencia.activa) avisar('Se activó el modo EMERGENCIA en tu barrio');
              if (antes && !emergencia.activa) avisar('Terminó el modo emergencia');
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'publicaciones',
            callback: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 800), refrescar);
            },
          )
          .subscribe();
    } catch (_) {
      // Sin tiempo real la app sigue funcionando con la consulta cada 30 s.
    }
  }

  Future<void> ubicar() async {
    final p = await Ubicacion.gps();
    if (p != null) {
      ubicacion = p;
      notifyListeners();
    }
  }

  void _cambioRed(bool hay) {
    final antes = online;
    _red = hay;
    notifyListeners();
    if (!antes && online) {
      avisar('Volvió el internet. Enviando lo pendiente...');
      sincronizar();
      refrescar();
    }
  }

  Future<void> cargarPerfil() async {
    if (!logueado) {
      perfil = null;
      await prefs.remove('perfil');
      notifyListeners();
      return;
    }
    try {
      final p = await repo.miPerfil();
      if (p != null) {
        perfil = p;
        await prefs.setString('perfil', jsonEncode(p));
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> actualizarEmergencia() async {
    try {
      final e = await repo.emergencia();
      if (e.activa != emergencia.activa || e.titulo != emergencia.titulo || e.mensaje != emergencia.mensaje) {
        emergencia = e;
        version++;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> sincronizar({bool silencioso = false}) async {
    final n = await repo.sincronizar();
    if (n > 0) {
      avisar(n == 1 ? 'Se envió 1 publicación guardada' : 'Se enviaron $n publicaciones guardadas');
      refrescar();
    } else if (!silencioso) {
      notifyListeners();
    }
  }

  void refrescar() {
    version++;
    notifyListeners();
    actualizarEmergencia();
    if (logueado) cargarPerfil(); // actualiza el nivel de reconocimiento
  }

  Future<bool> publicar(String tabla, Map<String, dynamic> datos) async {
    final enviado = await repo.publicar(tabla, datos);
    refrescar();
    return enviado;
  }

  void setEscala(double v) {
    escala = v;
    prefs.setDouble('escala', v);
    notifyListeners();
  }

  /// Botón "Aa": A → A+ → A++ → A. Devuelve el nombre del tamaño nuevo.
  String cambiarLetra() {
    const tamanos = [1.0, 1.3, 1.6];
    final i = tamanos.indexWhere((t) => (t - escala).abs() < 0.05);
    final nuevo = tamanos[(i + 1) % tamanos.length];
    setEscala(nuevo);
    return switch (nuevo) { 1.0 => 'normal', 1.3 => 'grande', _ => 'muy grande' };
  }

  void entrarComoInvitado() {
    invitado = true;
    prefs.setBool('modo_invitado', true);
    notifyListeners();
  }

  /// Inició sesión con una cuenta que ya existía: el tutorial y "¿Quién soy
  /// hoy?" son solo para cuentas nuevas, así que se saltan (aunque sea un
  /// celular nuevo). Si en este celular nunca eligió rol, se toma de su
  /// perfil (prestador o vecino).
  void entrarConCuentaExistente() {
    if (!prefs.containsKey('rol_simulado')) {
      rolSimulado = perfil?['es_prestador'] == true ? 'prestador' : 'vecino';
      prefs.setString('rol_simulado', rolSimulado);
    }
    tutorialVisto = true;
    rolElegido = true;
    invitado = false;
    prefs.setBool('tutorial_visto', true);
    prefs.setBool('rol_elegido', true);
    prefs.setBool('modo_invitado', false);
    notifyListeners();
  }

  /// Emergencia en la bienvenida: entra sin cuenta y sin pasos previos,
  /// directo a la pantalla de ayuda.
  void entrarEnEmergencia() {
    invitado = true;
    tutorialVisto = true;
    rolElegido = true;
    prefs.setBool('modo_invitado', true);
    prefs.setBool('tutorial_visto', true);
    prefs.setBool('rol_elegido', true);
    notifyListeners();
  }

  /// Cerrar sesión vuelve a la pantalla de bienvenida.
  Future<void> cerrarSesion() async {
    try {
      await repo.db.auth.signOut();
    } catch (_) {}
    invitado = false;
    await prefs.setBool('modo_invitado', false);
    await cargarPerfil();
  }

  void setAltoContraste(bool v) {
    altoContraste = v;
    prefs.setBool('alto_contraste', v);
    notifyListeners();
  }

  void setVoz(bool v) {
    voz = v;
    prefs.setBool('voz', v);
    notifyListeners();
  }

  void marcarTutorial(bool visto) {
    tutorialVisto = visto;
    prefs.setBool('tutorial_visto', visto);
    notifyListeners();
  }

  bool get esBrigadista => rolSimulado == 'brigadista';
  bool get esPrestadorRol => rolSimulado == 'prestador';

  void elegirRol(String rol, {String? oficio}) {
    rolSimulado = rol;
    rolElegido = true;
    prefs.setString('rol_simulado', rol);
    prefs.setBool('rol_elegido', true);
    if (oficio != null && oficio.trim().isNotEmpty) {
      especialidad = oficio.trim();
      prefs.setString('especialidad', especialidad!);
    }
    notifyListeners();
  }

  void setSimularOffline(bool v) {
    repo.forzarOffline = v;
    prefs.setBool('forzar_offline', v);
    notifyListeners();
    if (!v) {
      sincronizar();
      refrescar();
    }
  }

  @override
  void dispose() {
    _subRed?.cancel();
    _subAuth?.cancel();
    _timer?.cancel();
    _debounce?.cancel();
    if (_canal != null) repo.db.removeChannel(_canal!);
    super.dispose();
  }
}
