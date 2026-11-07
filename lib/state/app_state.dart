import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  bool _red = true;
  EstadoEmergencia emergencia = const EstadoEmergencia.inactiva();
  Map<String, dynamic>? perfil;
  Punto? ubicacion;
  int version = 0;

  StreamSubscription<List<ConnectivityResult>>? _subRed;
  StreamSubscription<dynamic>? _subAuth;
  Timer? _timer;

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
    unawaited(cargarPerfil());
    unawaited(actualizarEmergencia());
    unawaited(sincronizar(silencioso: true));
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => actualizarEmergencia());
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
    super.dispose();
  }
}
