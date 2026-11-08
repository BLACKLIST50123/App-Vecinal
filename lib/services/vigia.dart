import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'notificaciones.dart';

// Mismas credenciales que la app (se inyectan al compilar desde supabase.json).
const _url = String.fromEnvironment('SUPABASE_URL');
const _key = String.fromEnvironment('SUPABASE_ANON_KEY');

const _tareaPeriodica = 'vigia_periodico';
const _radioSosKm = 2.0;

/// Vigía del barrio: avisa de emergencias, SOS cercanos, pedidos de ayuda y
/// foro AUNQUE LA APP ESTÉ CERRADA, sin Firebase:
///  * Revisión periódica (WorkManager): cada ~15 min, aun con la app cerrada.
///  * Modo alerta (servicio en primer plano): revisa cada 30 s; se enciende
///    solo durante una emergencia o si el vecino lo activa.
/// Cada revisión consulta Supabase y muestra lo nuevo una sola vez.
class Vigia {
  static bool get soportado => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  // ------------------------------------------------------ revisión periódica

  static Future<void> programar() async {
    if (!soportado) return;
    try {
      await Workmanager().initialize(_despachador);
      await Workmanager().registerPeriodicTask(
        _tareaPeriodica,
        _tareaPeriodica,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint('Vigía periódico no disponible: $e');
    }
  }

  static Future<void> cancelar() async {
    if (!soportado) return;
    try {
      await Workmanager().cancelByUniqueName(_tareaPeriodica);
    } catch (_) {}
  }

  // ------------------------------------------------------ modo alerta

  static bool _configurado = false;

  static void _configurarServicio() {
    if (_configurado) return;
    _configurado = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'modo_alerta',
        channelName: 'Modo alerta',
        channelDescription: 'Mantiene a Conecta Vecino atento a emergencias y SOS.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false, playSound: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(30000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
      ),
    );
  }

  static Future<bool> get modoAlertaEncendido async {
    if (!soportado) return false;
    return FlutterForegroundTask.isRunningService;
  }

  static Future<void> encenderModoAlerta({required bool porEmergencia}) async {
    if (!soportado) return;
    try {
      _configurarServicio();
      final texto = porEmergencia
          ? 'Emergencia activa: te avisaremos al instante.'
          : 'Atento a emergencias y SOS de tu barrio.';
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.updateService(notificationTitle: 'Conecta Vecino · Modo alerta', notificationText: texto);
        return;
      }
      await FlutterForegroundTask.startService(
        serviceId: 700,
        serviceTypes: [ForegroundServiceTypes.remoteMessaging],
        notificationTitle: 'Conecta Vecino · Modo alerta',
        notificationText: texto,
        callback: _iniciarServicio,
      );
    } catch (e) {
      debugPrint('No se pudo encender el modo alerta: $e');
    }
  }

  static Future<void> apagarModoAlerta() async {
    if (!soportado) return;
    try {
      if (await FlutterForegroundTask.isRunningService) await FlutterForegroundTask.stopService();
    } catch (_) {}
  }

  // ------------------------------------------------------ estado compartido

  /// Lo que el vecino ya vio con la app abierta no se vuelve a avisar.
  static Future<void> marcarVisto({required bool emergenciaActiva}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('vigia_desde', DateTime.now().toUtc().toIso8601String());
    await p.setBool('vigia_emergencia', emergenciaActiva);
  }

  /// Punto de referencia y cuenta del vecino, para SOS cercanos y no
  /// avisarle de lo que él mismo publicó.
  static Future<void> guardarContexto({required double lat, required double lng, String? uid}) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('vigia_lat', lat);
    await p.setDouble('vigia_lng', lng);
    if (uid != null) {
      await p.setString('vigia_uid', uid);
    } else {
      await p.remove('vigia_uid');
    }
  }

  // ------------------------------------------------------ la revisión

  static bool _revisando = false;

  /// Consulta Supabase y avisa lo nuevo. Sirve en cualquier isolate
  /// (app, WorkManager o servicio en primer plano). Devuelve cuántos avisó.
  static Future<int> revisar() async {
    if (_revisando || _url.isEmpty || _key.isEmpty) return 0;
    _revisando = true;
    var avisados = 0;
    SupabaseClient? db;
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload(); // otro isolate pudo cambiar los datos
      if (p.getBool('avisos_activados') != true) return 0;
      bool quiere(TipoAviso t) => p.getBool('aviso_${t.name}') ?? t.porDefecto;

      final ahora = DateTime.now().toUtc();
      final desdeTxt = p.getString('vigia_desde');
      // Primera vez: no avisar de lo viejo.
      final desde = desdeTxt == null ? ahora : DateTime.parse(desdeTxt);
      final yaAvisados = (p.getStringList('vigia_ids') ?? []).toSet();
      final nuevos = <String>[];
      final uid = p.getString('vigia_uid');
      final lat = p.getDouble('vigia_lat'), lng = p.getDouble('vigia_lng');

      db = SupabaseClient(_url, _key, authOptions: const AuthClientOptions(autoRefreshToken: false));

      // 1. Modo emergencia del barrio (cambió desde la última vez).
      final e = await db.from('emergencia').select('activa, titulo').eq('id', 1).maybeSingle();
      if (e != null) {
        final activa = e['activa'] == true;
        final antes = p.getBool('vigia_emergencia') ?? false;
        if (activa != antes) {
          await p.setBool('vigia_emergencia', activa);
          if (quiere(TipoAviso.emergencia)) {
            await Notificaciones.mostrar(
              TipoAviso.emergencia,
              activa ? 'EMERGENCIA en tu barrio' : 'Terminó la emergencia',
              activa ? '${e['titulo'] ?? 'La junta vecinal activó el modo emergencia.'}' : 'Tu barrio volvió a la normalidad.',
              clave: 'emergencia-$activa',
            );
            avisados++;
          }
        }
      }

      // 2. SOS cercanos y pedidos de ayuda nuevos.
      final pubs = await db
          .from('publicaciones')
          .select('id, titulo, tipo, origen, lat, lng, autor_id')
          .gt('created_at', desde.toIso8601String())
          .neq('estado', 'resuelta')
          .order('created_at')
          .limit(20);
      for (final f in pubs) {
        final id = '${f['id']}';
        if (yaAvisados.contains(id) || (uid != null && f['autor_id'] == uid)) continue;
        if (f['origen'] == 'sos') {
          if (!quiere(TipoAviso.sosCercano)) continue;
          final plat = (f['lat'] as num?)?.toDouble(), plng = (f['lng'] as num?)?.toDouble();
          String cuerpo = '${f['titulo'] ?? 'Un vecino pidió ayuda urgente.'}';
          if (lat != null && lng != null && plat != null && plng != null) {
            final km = _distanciaKm(lat, lng, plat, plng);
            if (km > _radioSosKm) continue;
            cuerpo += km < 1 ? ' · a ${(km * 1000).round()} m' : ' · a ${km.toStringAsFixed(1)} km';
          }
          await Notificaciones.mostrar(TipoAviso.sosCercano, '🆘 SOS cerca de ti', cuerpo, clave: id);
        } else if (f['tipo'] == 'pido') {
          if (!quiere(TipoAviso.pedidosAyuda)) continue;
          await Notificaciones.mostrar(TipoAviso.pedidosAyuda, 'Un vecino necesita una mano', '${f['titulo'] ?? ''}', clave: id);
        } else {
          continue;
        }
        nuevos.add(id);
        avisados++;
      }

      // 3. Foro (solo si lo encendió).
      if (quiere(TipoAviso.foro)) {
        try {
          final temas = await db
              .from('foro_temas')
              .select('id, titulo, autor_id')
              .gt('created_at', desde.toIso8601String())
              .order('created_at')
              .limit(5);
          for (final t in temas) {
            final id = '${t['id']}';
            if (yaAvisados.contains(id) || (uid != null && t['autor_id'] == uid)) continue;
            await Notificaciones.mostrar(TipoAviso.foro, 'Nuevo tema en el foro', '${t['titulo'] ?? ''}', clave: id);
            nuevos.add(id);
            avisados++;
          }
        } catch (_) {}
      }

      final ids = [...yaAvisados, ...nuevos];
      await p.setStringList('vigia_ids', ids.length > 80 ? ids.sublist(ids.length - 80) : ids);
      await p.setString('vigia_desde', ahora.toIso8601String());
    } catch (e) {
      debugPrint('Vigía: no se pudo revisar ($e)');
    } finally {
      _revisando = false;
      await db?.dispose();
    }
    return avisados;
  }

  static double _distanciaKm(double lat1, double lng1, double lat2, double lng2) {
    double rad(double g) => g * pi / 180;
    final a = pow(sin(rad(lat2 - lat1) / 2), 2) + cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(rad(lng2 - lng1) / 2), 2);
    return 6371 * 2 * asin(sqrt(a));
  }
}

// ---------------------------------------------------------- puntos de entrada

/// WorkManager: se ejecuta en segundo plano aunque la app esté cerrada.
@pragma('vm:entry-point')
void _despachador() {
  Workmanager().executeTask((tarea, datos) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    await Vigia.revisar();
    return true;
  });
}

/// Servicio en primer plano (modo alerta).
@pragma('vm:entry-point')
void _iniciarServicio() {
  FlutterForegroundTask.setTaskHandler(_ManejadorAlerta());
}

class _ManejadorAlerta extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    DartPluginRegistrant.ensureInitialized();
    await Vigia.revisar();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(Vigia.revisar());
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();
}
