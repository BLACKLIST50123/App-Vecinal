import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../data/repo.dart';
import '../features/sos/sos_navegacion.dart';
import '../models.dart';
import '../services/notificaciones.dart';
import '../services/push.dart';
import '../services/ubicacion.dart';
import '../util.dart';

final mensajero = GlobalKey<ScaffoldMessengerState>();

/// La acción no está permitida (no es un problema de red): se muestra el
/// mensaje tal cual, con los números de emergencia.
class SinPermiso implements Exception {
  const SinPermiso(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

void avisar(String texto) {
  mensajero.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto), duration: const Duration(seconds: 5)));
}

/// Estado global: sesión, rol, modo emergencia, conexión y accesibilidad.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState(this.prefs, this.repo) {
    WidgetsBinding.instance.addObserver(this);
    escala = prefs.getDouble('escala') ?? 1.0;
    altoContraste = prefs.getBool('alto_contraste') ?? false;
    voz = prefs.getBool('voz') ?? true;
    tutorialVisto = prefs.getBool('tutorial_visto') ?? false;
    final b = prefs.getString('brigadista');
    if (b != null) {
      try {
        brigadista = Brigadista.fromMap(Map<String, dynamic>.from(jsonDecode(b) as Map));
      } catch (_) {}
    }
    // El modo invitado no se recuerda: cada vez que se abre la app sin
    // cuenta se vuelve a la bienvenida (invitando a crear una cuenta).
    invitado = false;
    repo.forzarOffline = prefs.getBool('forzar_offline') ?? false;
    avisosActivados = prefs.getBool('avisos_activados') ?? false;
    for (final t in TipoAviso.values) {
      avisos[t] = prefs.getBool('aviso_${t.name}') ?? t.porDefecto;
    }
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

  /// Ya pasó por "Activar notificaciones" (y dio permiso al sistema).
  late bool avisosActivados;

  /// Permiso del sistema para mostrar avisos (null = no aplica, p. ej. web).
  bool? permisoAvisos;

  /// Preferencia de cada tipo de aviso.
  final avisos = <TipoAviso, bool>{};

  /// Recordatorio (puntito en Perfil): faltan activar los avisos, el
  /// sistema los bloquea o se apagaron los de emergencia (los más importantes).
  bool get faltaActivarAvisos =>
      !avisosActivados || permisoAvisos == false || TipoAviso.values.any((t) => t.critico && avisos[t] != true);

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
    unawaited(revisarPermisoAvisos());
    unawaited(_ubicarEnSilencio());
    Push.alRenovarToken = () => unawaited(registrarPush());
    unawaited(registrarPush()); // token del celular para avisos con la app cerrada
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
              if (!antes && emergencia.activa) {
                avisar('Se activó el modo EMERGENCIA en tu barrio');
                notificar(TipoAviso.emergencia, 'EMERGENCIA en tu barrio',
                    emergencia.titulo ?? 'La junta vecinal activó el modo emergencia.', mensajeInterno: false);
              }
              if (antes && !emergencia.activa) {
                avisar('Terminó el modo emergencia');
                notificar(TipoAviso.emergencia, 'Terminó la emergencia', 'Tu barrio volvió a la normalidad.',
                    mensajeInterno: false);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'publicaciones',
            callback: (cambio) {
              if (cambio.eventType == PostgresChangeEvent.insert) {
                _avisarSiEsSosCercano(cambio.newRecord);
                _avisarSiEsPedidoDeAyuda(cambio.newRecord);
              }
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 800), refrescar);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'pedidos_servicio',
            callback: (cambio) {
              final f = cambio.newRecord;
              if (cambio.eventType == PostgresChangeEvent.insert && uid != null && f['prestador_id'] == uid) {
                notificar(TipoAviso.misServicios, 'Nuevo pedido a tu servicio',
                    '${f['cliente_nombre'] ?? 'Un vecino'}: ${f['detalle'] ?? ''}');
              }
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 800), refrescar);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'foro_temas',
            callback: (cambio) {
              final f = cambio.newRecord;
              if (f['autor_id'] != null && f['autor_id'] == uid) return;
              notificar(TipoAviso.foro, 'Nuevo tema en el foro', '${f['titulo'] ?? ''}');
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'estados_vecino',
            callback: (_) {
              // Conteo de vecinos a salvo (junta, organizaciones, brigadistas).
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 800), refrescar);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'brigadistas',
            callback: (cambio) {
              // Me nombraron (o me quitaron) brigadista: se ve al instante.
              final fila = cambio.newRecord.isNotEmpty ? cambio.newRecord : cambio.oldRecord;
              final antes = brigadista;
              if (fila['vecino_id'] == uid || (antes != null && cambio.eventType == PostgresChangeEvent.delete)) {
                cargarPerfil().then((_) {
                  if (antes == null && tieneInvitacionBrigadista) {
                    avisar('La junta vecinal te nombró brigadista. Revisa tu Perfil.');
                  }
                });
              }
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 800), refrescar);
            },
          )
          .subscribe();
    } catch (_) {
      // Sin tiempo real la app sigue funcionando con la consulta cada 30 s.
    }
  }

  /// Un SOS nuevo a ≤ 2 km (y que no es mío) se avisa al instante, con
  /// vibración, para que los vecinos más cercanos puedan ayudar.
  /// Los avisos reservados solo llegan a quien el servidor deja verlos.
  void _avisarSiEsSosCercano(Map<String, dynamic> fila) {
    try {
      if (fila['origen'] != 'sos' || fila['id'] == null) return;
      final p = Publicacion.fromMap(fila);
      if (p.autorId != null && p.autorId == uid) return;
      if (p.punto == null) return;
      final km = distanciaKm(referencia, p.punto!);
      if (km > radioAlertaKm) return;
      alertaEntrante.value = (p, km);
      HapticFeedback.vibrate();
      // En pantalla ya se ve la alerta; en segundo plano, a la barra del celular.
      notificar(TipoAviso.sosCercano, 'SOS cerca de ti', '${p.titulo} · ${formatoDistancia(km)}', mensajeInterno: false);
    } catch (_) {}
  }

  /// Un pedido de ayuda nuevo (no SOS, no mío) en el día a día del barrio.
  void _avisarSiEsPedidoDeAyuda(Map<String, dynamic> fila) {
    if (fila['tipo'] != 'pido' || fila['origen'] == 'sos') return;
    if (fila['autor_id'] != null && fila['autor_id'] == uid) return;
    notificar(TipoAviso.pedidosAyuda, 'Un vecino necesita una mano', '${fila['titulo'] ?? ''}');
  }

  Future<void> ubicar() async {
    final p = await Ubicacion.gps();
    if (p != null) _nuevaUbicacion(p);
  }

  /// Al abrir la app: actualiza la ubicación solo si ya hay permiso (sin
  /// diálogos), para que los SOS cercanos lleguen a quien de verdad está cerca.
  Future<void> _ubicarEnSilencio() async {
    final p = await Ubicacion.gpsSiHayPermiso();
    if (p != null) _nuevaUbicacion(p);
  }

  void _nuevaUbicacion(Punto p) {
    ubicacion = p;
    notifyListeners();
    // El servidor usa esta ubicación (aproximada) para los SOS a ≤ 2 km.
    unawaited(registrarPush());
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
      unawaited(registrarPush());
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
    try {
      brigadista = await repo.miNombramiento();
      if (brigadista == null) {
        await prefs.remove('brigadista');
      } else {
        await prefs.setString('brigadista', jsonEncode(brigadista!.toJson()));
      }
    } catch (_) {} // sin la migración 0010 simplemente no hay brigadistas
    unawaited(registrarPush()); // vincula el celular con la cuenta
    notifyListeners();
  }

  Future<void> actualizarEmergencia() async {
    try {
      final e = await repo.emergencia();
      if (e.activa != emergencia.activa ||
          e.titulo != emergencia.titulo ||
          e.mensaje != emergencia.mensaje ||
          e.clave != emergencia.clave) {
        emergencia = e;
        version++;
        notifyListeners();
      }
      await _cargarMiEstado();
    } catch (_) {}
  }

  // ------------------------------------------------- "Estoy bien" (0012)

  /// Lo que respondí en esta emergencia: 'bien', 'ayuda' o null.
  String? miEstado;

  /// Clave de la emergencia a la que corresponde [miEstado].
  String? _estadoDe;

  Future<void> _cargarMiEstado() async {
    final clave = emergencia.clave;
    if (!emergencia.activa || clave == null || !logueado) {
      if (miEstado != null) {
        miEstado = null;
        notifyListeners();
      }
      return;
    }
    // Sin señal: lo último que respondí en esta emergencia (guardado aquí).
    final pendiente = prefs.getString('estado_pendiente_$clave');
    if (pendiente != null) {
      miEstado = pendiente;
      notifyListeners();
      return;
    }
    if (_estadoDe == clave && miEstado != null) return;
    try {
      miEstado = await repo.miEstado(clave);
      _estadoDe = clave;
      notifyListeners();
    } catch (_) {} // sin la migración 0012 o sin señal: se muestra sin responder
  }

  /// "Estoy bien" o "Necesito ayuda". Sin señal queda guardado y se envía al volver.
  Future<void> marcarEstado(String estado) async {
    final clave = emergencia.clave;
    if (clave == null || !logueado) return;
    miEstado = estado;
    _estadoDe = clave;
    notifyListeners();
    try {
      await repo.marcarEstado(emergencia: clave, estado: estado, sector: sector);
      await prefs.remove('estado_pendiente_$clave');
    } catch (e) {
      if (Repo.esErrorDeRed(e)) {
        await prefs.setString('estado_pendiente_$clave', estado);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _enviarEstadoPendiente() async {
    final clave = emergencia.clave;
    if (clave == null || !logueado) return;
    final pendiente = prefs.getString('estado_pendiente_$clave');
    if (pendiente == null) return;
    try {
      await repo.marcarEstado(emergencia: clave, estado: pendiente, sector: sector);
      await prefs.remove('estado_pendiente_$clave');
    } catch (_) {}
  }

  Future<void> sincronizar({bool silencioso = false}) async {
    await _enviarEstadoPendiente();
    final (n, rechazadas) = await repo.sincronizar();
    if (rechazadas.isNotEmpty) {
      // Nunca dejar una alerta "guardada" que en realidad no se enviará.
      final hayEmergencia = rechazadas.any((e) => e.datos['es_emergencia'] == true);
      avisar(hayEmergencia
          ? 'No se pudo enviar tu pedido de ayuda. Si es urgente, llama al 105 (Policía), 106 (SAMU) o 116 (Bomberos).'
          : 'No se pudo enviar una publicación guardada. Revísala en "Llevar mensajes".');
      notifyListeners();
    }
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
    // Sin cuenta, un pedido normal solo se acepta con emergencia activa (D5).
    // Se avisa ahora, en vez de guardarlo en la cola y que falle en silencio.
    if (!logueado && datos['origen'] == 'sin_cuenta' && !modoEmergencia) {
      throw const SinPermiso(
        'Sin cuenta solo puedes pedir ayuda cuando la junta activa la emergencia. '
        'Usa el botón SOS, o si es urgente llama al 105, 106 o 116.',
      );
    }
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
    // Los invitados ven el tutorial siempre que entran (se puede saltar).
    tutorialVisto = false;
    notifyListeners();
  }

  /// Inició sesión con una cuenta que ya existía: el tutorial es solo para
  /// cuentas nuevas, así que se salta (aunque sea un celular nuevo).
  void entrarConCuentaExistente() {
    tutorialVisto = true;
    invitado = false;
    prefs.setBool('tutorial_visto', true);
    notifyListeners();
  }

  /// Emergencia en la bienvenida: entra sin cuenta y sin pasos previos,
  /// directo a la pantalla de ayuda.
  void entrarEnEmergencia() {
    invitado = true;
    tutorialVisto = true; // en emergencia no se muestra el tutorial
    prefs.setBool('tutorial_visto', true);
    notifyListeners();
  }

  /// Cerrar sesión vuelve a la pantalla de bienvenida.
  Future<void> cerrarSesion() async {
    try {
      await repo.db.auth.signOut();
    } catch (_) {}
    invitado = false;
    await cargarPerfil();
  }

  void setAltoContraste(bool v) {
    altoContraste = v;
    prefs.setBool('alto_contraste', v);
    notifyListeners();
  }

  // ------------------------------------------------------- notificaciones

  Future<void> revisarPermisoAvisos() async {
    final p = await Notificaciones.permitidas();
    if (p != permisoAvisos) {
      permisoAvisos = p;
      notifyListeners();
    }
  }

  /// Activa los avisos: pide permiso al sistema y enciende los de emergencia.
  /// Devuelve false si el vecino negó el permiso.
  Future<bool> activarAvisos() async {
    final ok = await Notificaciones.pedirPermiso();
    permisoAvisos = await Notificaciones.permitidas() ?? (ok ? true : null);
    if (ok) {
      avisosActivados = true;
      await prefs.setBool('avisos_activados', true);
      for (final t in TipoAviso.values.where((t) => t.critico)) {
        avisos[t] = true;
        await prefs.setBool('aviso_${t.name}', true);
      }
      unawaited(registrarPush());
    }
    notifyListeners();
    return ok;
  }

  void setAviso(TipoAviso t, bool v) {
    avisos[t] = v;
    prefs.setBool('aviso_${t.name}', v);
    notifyListeners();
    unawaited(registrarPush());
  }

  /// Envía al servidor este celular y lo que quiere recibir, para que los
  /// push lleguen aunque la app esté cerrada. La ubicación va aproximada.
  Future<void> registrarPush() async {
    if (!avisosActivados) return;
    final p = aproximar(referencia);
    await Push.registrar(db: repo.db, avisos: avisos, sector: sector, lat: p.lat, lng: p.lng);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(revisarPermisoAvisos());
  }

  /// Muestra un aviso si el vecino lo tiene encendido.
  /// * App abierta: mensaje en pantalla.
  /// * App cerrada o en segundo plano: lo envía el servidor por Firebase
  ///   (Edge Function `enviar-avisos`). Si Firebase no está configurado
  ///   (p. ej. sin claves), se muestra un aviso local mientras la app viva.
  void notificar(TipoAviso t, String titulo, String cuerpo, {bool mensajeInterno = true}) {
    if (avisos[t] != true) return;
    final enPantalla = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (enPantalla) {
      if (mensajeInterno) avisar('$titulo: $cuerpo');
    } else if (avisosActivados && !Push.activo) {
      Notificaciones.mostrar(t, titulo, cuerpo);
    }
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

  /// Nombramiento como brigadista hecho por la junta de su sector.
  Brigadista? brigadista;

  /// Brigadista activo (aceptó el nombramiento de la junta).
  bool get esBrigadista => logueado && brigadista?.activo == true;

  /// La junta lo nombró y falta que acepte.
  bool get tieneInvitacionBrigadista => logueado && brigadista?.invitado == true;
  bool get esPrestador => perfil?['es_prestador'] == true;

  /// URL de la foto de perfil (null = se muestran las iniciales).
  String? get fotoUrl => perfil?['foto_url'] as String?;

  Future<void> responderNombramiento(bool aceptar) async {
    if (aceptar) {
      await repo.aceptarNombramiento();
    } else {
      await repo.quitarBrigadista(uid!);
    }
    await cargarPerfil();
    version++;
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
