import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notificaciones.dart';

// Claves de Firebase: se inyectan al compilar desde supabase.json, igual que
// las de Supabase. Si faltan, la app funciona sin push (solo avisos locales).
const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
const _appId = String.fromEnvironment('FIREBASE_APP_ID');
const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

/// Notificaciones push (Firebase Cloud Messaging): llegan aunque la app
/// esté cerrada. El servidor (Edge Function `enviar-avisos`) decide a quién
/// enviar según las preferencias guardadas en la tabla `dispositivos`.
class Push {
  static bool _listo = false;
  static String? _token;

  static bool get configurado =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android && _apiKey.isNotEmpty && _appId.isNotEmpty;

  /// true cuando este celular ya está registrado para recibir push.
  static bool get activo => _listo && _token != null;

  static Future<void> iniciar() async {
    if (!configurado || _listo) return;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _senderId,
          projectId: _projectId,
        ),
      );
      // Los canales deben existir antes de que llegue un push con la app cerrada.
      await Notificaciones.crearCanales();
      // getToken() sigue siendo el token que acepta FCM v1 (message.token).
      // ignore: deprecated_member_use
      _token = await FirebaseMessaging.instance.getToken();
      _listo = true;
      // ignore: deprecated_member_use
      FirebaseMessaging.instance.onTokenRefresh.listen((t) => _token = t);
    } catch (e) {
      debugPrint('Push sin configurar: $e');
    }
  }

  /// Guarda (o actualiza) este celular y sus preferencias en Supabase.
  /// Funciona con o sin cuenta: los invitados también reciben emergencias.
  static Future<void> registrar({
    required SupabaseClient db,
    required Map<TipoAviso, bool> avisos,
    String? sector,
    double? lat,
    double? lng,
  }) async {
    if (!configurado) return;
    await iniciar();
    final token = _token;
    if (token == null) return;
    try {
      await db.rpc('registrar_dispositivo', params: {
        'p_token': token,
        'p_emergencia': avisos[TipoAviso.emergencia] == true,
        'p_sos_cercano': avisos[TipoAviso.sosCercano] == true,
        'p_pedidos_ayuda': avisos[TipoAviso.pedidosAyuda] == true,
        'p_mis_servicios': avisos[TipoAviso.misServicios] == true,
        'p_foro': avisos[TipoAviso.foro] == true,
        'p_sector': sector,
        'p_lat': lat,
        'p_lng': lng,
      });
    } catch (e) {
      debugPrint('No se pudo registrar el dispositivo: $e');
    }
  }
}
