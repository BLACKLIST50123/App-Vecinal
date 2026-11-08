import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Tipos de aviso que el vecino puede activar o desactivar.
/// [critico] = emergencias: se recomiendan siempre encendidos.
enum TipoAviso {
  emergencia(
    'Modo emergencia del barrio',
    'Cuando la junta vecinal activa o termina una emergencia (sismo, inundación...).',
    Icons.campaign_outlined,
    critico: true,
  ),
  sosCercano(
    'Alertas SOS cerca de ti',
    'Un vecino a menos de 2 km pidió ayuda urgente.',
    Icons.sos_outlined,
    critico: true,
  ),
  pedidosAyuda(
    'Pedidos de ayuda en tu barrio',
    'Alguien necesita una mano: compras, compañía, préstamos...',
    Icons.volunteer_activism_outlined,
  ),
  misServicios(
    'Pedidos a mis servicios',
    'Un vecino te pidió un servicio o producto que ofreces.',
    Icons.storefront_outlined,
  ),
  foro(
    'Novedades del foro',
    'Nuevos temas y preguntas de tus vecinos.',
    Icons.forum_outlined,
    porDefecto: false,
  );

  const TipoAviso(this.titulo, this.descripcion, this.icono, {this.critico = false, this.porDefecto = true});
  final String titulo;
  final String descripcion;
  final IconData icono;
  final bool critico;
  final bool porDefecto;
}

/// Avisos del sistema (barra de notificaciones del celular).
/// En web no hay avisos del sistema: la app muestra el mensaje dentro.
class Notificaciones {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _listo = false;
  static int _id = 0;

  /// En web solo se usan los mensajes dentro de la app.
  static bool get soportado => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static Future<void> iniciar() async {
    if (!soportado || _listo) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      );
      _listo = true;
      await crearCanales();
    } catch (e) {
      debugPrint("Notificaciones.iniciar falló: $e");
      // Si falla, la app sigue con los mensajes internos.
    }
  }

  static const _canalEmergencias = AndroidNotificationChannel(
    'emergencias',
    'Emergencias y SOS',
    description: 'Avisos urgentes: modo emergencia y SOS cercanos.',
    importance: Importance.max,
  );
  static const _canalAvisos = AndroidNotificationChannel(
    'avisos',
    'Avisos del barrio',
    description: 'Pedidos de ayuda, servicios y foro.',
  );

  /// Crea los canales de Android. Los push que llegan con la app cerrada
  /// indican su canal ("emergencias" o "avisos"), que debe existir antes.
  static Future<void> crearCanales() async {
    if (!soportado) return;
    try {
      await _android?.createNotificationChannel(_canalEmergencias);
      await _android?.createNotificationChannel(_canalAvisos);
    } catch (e) {
      debugPrint("Notificaciones: $e");
    }
  }

  /// true si el sistema deja mostrar avisos; null si no aplica (web).
  static Future<bool?> permitidas() async {
    if (!soportado) return null;
    await iniciar();
    try {
      return await _android?.areNotificationsEnabled();
    } catch (_) {
      return null;
    }
  }

  /// Pide el permiso del sistema (Android 13+ muestra el diálogo).
  static Future<bool> pedirPermiso() async {
    if (!soportado) return true;
    await iniciar();
    try {
      final r = await _android?.requestNotificationsPermission();
      return r ?? await permitidas() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// [clave]: el mismo evento usa siempre el mismo id, así nunca sale repetido.
  static Future<void> mostrar(TipoAviso tipo, String titulo, String cuerpo, {String? clave}) async {
    if (!soportado) return;
    await iniciar();
    if (!_listo) return;
    final detalles = tipo.critico
        ? const AndroidNotificationDetails(
            'emergencias',
            'Emergencias y SOS',
            channelDescription: 'Avisos urgentes: modo emergencia y SOS cercanos.',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            color: Color(0xFFE53935),
          )
        : const AndroidNotificationDetails(
            'avisos',
            'Avisos del barrio',
            channelDescription: 'Pedidos de ayuda, servicios y foro.',
            importance: Importance.defaultImportance,
            color: Color(0xFF1E293B),
          );
    try {
      await _plugin.show(
        id: clave != null ? clave.hashCode & 0x7fffffff : _id++,
        title: titulo,
        body: cuerpo,
        notificationDetails: NotificationDetails(android: detalles),
      );
    } catch (e) {
      debugPrint("Notificaciones: $e");
    }
  }
}
