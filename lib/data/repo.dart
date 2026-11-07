import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';

/// Publicación creada sin conexión (o traída por QR) que espera enviarse.
class EntradaPendiente {
  EntradaPendiente({required this.tabla, required this.datos, this.viaQr = false, this.error});

  final String tabla; // 'publicaciones' | 'servicios'
  final Map<String, dynamic> datos;
  final bool viaQr;
  String? error;

  String get id => datos['id'] as String;
  String get titulo => (datos['titulo'] ?? '') as String;

  Map<String, dynamic> toJson() => {'tabla': tabla, 'datos': datos, 'via_qr': viaQr, 'error': error};

  factory EntradaPendiente.fromJson(Map<String, dynamic> j) => EntradaPendiente(
        tabla: j['tabla'] as String,
        datos: Map<String, dynamic>.from(j['datos'] as Map),
        viaQr: j['via_qr'] == true,
        error: j['error'] as String?,
      );
}

/// Acceso a datos con estrategia offline-first:
/// - Lecturas: se guardan en caché; sin red se muestra la última copia.
/// - Escrituras: si no hay red, van a una cola local y se envían luego.
///   Los IDs se generan en el teléfono, así reenviar nunca duplica.
class Repo {
  Repo(this.prefs, this.db) {
    _cargarCola();
  }

  final SharedPreferences prefs;
  final SupabaseClient db;
  bool forzarOffline = false;
  final List<EntradaPendiente> pendientes = [];

  String? get uid => db.auth.currentUser?.id;

  /// true si el error es de red (sin internet / tiempo agotado) y no un
  /// rechazo del servidor (permisos, datos inválidos).
  static bool esErrorDeRed(Object e) =>
      e is! PostgrestException && e is! AuthException && e is! FormatException && e is! TypeError;

  void _cargarCola() {
    final raw = prefs.getString('cola_envio');
    if (raw == null) return;
    try {
      pendientes.addAll((jsonDecode(raw) as List)
          .map((e) => EntradaPendiente.fromJson(Map<String, dynamic>.from(e as Map))));
    } catch (_) {}
  }

  Future<void> _guardarCola() =>
      prefs.setString('cola_envio', jsonEncode(pendientes.map((e) => e.toJson()).toList()));

  Future<List<Map<String, dynamic>>> _consultar(
      String clave, Future<List<Map<String, dynamic>>> Function() consulta) async {
    if (!forzarOffline) {
      try {
        final r = await consulta().timeout(const Duration(seconds: 10));
        await prefs.setString('cache_$clave', jsonEncode(r));
        return r;
      } catch (e) {
        if (!esErrorDeRed(e)) rethrow;
      }
    }
    final raw = prefs.getString('cache_$clave');
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ------------------------------------------------------------ lecturas

  Future<List<Servicio>> servicios({required bool emergencia}) async {
    final filas = await _consultar(
      'servicios_$emergencia',
      () => db
          .from('servicios')
          .select('*, vistos_buenos(count)')
          .eq('activo', true)
          .eq('es_emergencia', emergencia)
          .order('created_at', ascending: false)
          .limit(300),
    );
    final enviados = filas.map(Servicio.fromMap).toList();
    final ids = enviados.map((s) => s.id).toSet();
    return [
      ...pendientes
          .where((p) =>
              p.tabla == 'servicios' &&
              (p.datos['es_emergencia'] == true) == emergencia &&
              !ids.contains(p.id))
          .map((p) => Servicio.fromMap(p.datos, pendiente: true)),
      ...enviados,
    ];
  }

  Future<List<Publicacion>> publicaciones({required bool emergencia}) async {
    final filas = await _consultar(
      'publicaciones_$emergencia',
      () => db
          .from('publicaciones')
          .select('*, ayudas(count)')
          .eq('es_emergencia', emergencia)
          .neq('estado', 'resuelta')
          .order('created_at', ascending: false)
          .limit(300),
    );
    final enviadas = filas.map(Publicacion.fromMap).toList();
    final ids = enviadas.map((p) => p.id).toSet();
    return [
      ...pendientes
          .where((p) =>
              p.tabla == 'publicaciones' &&
              (p.datos['es_emergencia'] == true) == emergencia &&
              !ids.contains(p.id))
          .map((p) => Publicacion.fromMap(p.datos, pendiente: true)),
      ...enviadas,
    ];
  }

  Future<EstadoEmergencia> emergencia() async {
    final filas = await _consultar('emergencia', () async {
      final r = await db.from('emergencia').select().eq('id', 1).maybeSingle();
      return r == null ? <Map<String, dynamic>>[] : [r];
    });
    return filas.isEmpty ? const EstadoEmergencia.inactiva() : EstadoEmergencia.fromMap(filas.first);
  }

  Future<List<VistoBueno>> vistosBuenos(String servicioId) async {
    final filas = await _consultar(
      'vb_$servicioId',
      () => db
          .from('vistos_buenos')
          .select('id, autor_id, autor_nombre, autor_verificado, comentario, created_at')
          .eq('servicio_id', servicioId)
          .order('created_at', ascending: false),
    );
    return filas.map(VistoBueno.fromMap).toList();
  }

  Future<List<Ayuda>> ayudas(String publicacionId) async {
    final filas = await _consultar(
      'ayudas_$publicacionId',
      () => db
          .from('ayudas')
          .select('vecino_id, vecino_nombre, created_at')
          .eq('publicacion_id', publicacionId)
          .order('created_at'),
    );
    return filas.map(Ayuda.fromMap).toList();
  }

  /// Todo lo que publicó el usuario (incluye resueltas e inactivas).
  Future<(List<Publicacion>, List<Servicio>)> misPublicaciones() async {
    final id = uid;
    if (id == null) return (<Publicacion>[], <Servicio>[]);
    final pubs = await _consultar(
      'mis_pubs_$id',
      () => db.from('publicaciones').select('*, ayudas(count)').eq('autor_id', id).order('created_at', ascending: false),
    );
    final servs = await _consultar(
      'mis_servs_$id',
      () => db.from('servicios').select('*, vistos_buenos(count)').eq('autor_id', id).order('created_at', ascending: false),
    );
    return (pubs.map(Publicacion.fromMap).toList(), servs.map(Servicio.fromMap).toList());
  }

  // ------------------------------------------- confianza y coordinación

  Future<void> reportar({
    required String tabla,
    required String id,
    required String titulo,
    required String motivo,
    String? detalle,
  }) =>
      db.from('reportes').insert({
        'tabla': tabla,
        'objeto_id': id,
        'titulo': titulo,
        'motivo': motivo,
        if (detalle != null && detalle.trim().isNotEmpty) 'detalle': detalle.trim(),
      });

  /// Reportes sin revisar (solo los ve el moderador, lo valida RLS).
  Future<List<Map<String, dynamic>>> reportesPendientes() => db
      .from('reportes')
      .select('id, tabla, objeto_id, titulo, motivo, detalle, created_at')
      .eq('revisado', false)
      .order('created_at', ascending: false);

  Future<void> marcarReportesRevisados(String tabla, String objetoId) =>
      db.from('reportes').update({'revisado': true}).eq('tabla', tabla).eq('objeto_id', objetoId);

  Future<void> verificar(String id, {required bool verificada, required String estadoActual}) =>
      db.from('publicaciones').update({
        'verificada': verificada,
        if (!verificada) 'estado': 'no_verificado',
        if (verificada && estadoActual == 'no_verificado') 'estado': 'abierta',
      }).eq('id', id);

  /// Indicadores para el panel de coordinación (todas las publicaciones,
  /// incluidas las atendidas).
  Future<Map<String, int>> indicadores({required bool emergencia}) async {
    final filas = await _consultar(
      'indicadores_$emergencia',
      () => db.from('publicaciones').select('estado, tipo, verificada, ayudas(count)').eq('es_emergencia', emergencia).limit(2000),
    );
    final r = <String, int>{'abierta': 0, 'en_curso': 0, 'resuelta': 0, 'no_verificado': 0, 'verificadas': 0, 'ayudantes': 0, 'total': 0};
    for (final f in filas) {
      final e = (f['estado'] ?? 'abierta') as String;
      r[e] = (r[e] ?? 0) + 1;
      r['total'] = r['total']! + 1;
      if (f['verificada'] == true) r['verificadas'] = r['verificadas']! + 1;
      r['ayudantes'] = r['ayudantes']! + _contar(f['ayudas']);
    }
    return r;
  }

  static int _contar(dynamic x) =>
      x is List && x.isNotEmpty && x.first is Map ? (((x.first as Map)['count'] as num?)?.toInt() ?? 0) : 0;

  /// Colectas: quien organiza anota las donaciones recibidas en persona.
  Future<void> actualizarAvance(String id, int avance) =>
      db.from('publicaciones').update({'avance': avance}).eq('id', id);

  Future<void> ofrecerAyuda(String publicacionId) =>
      db.from('ayudas').insert({'publicacion_id': publicacionId});

  Future<void> retirarAyuda(String publicacionId) =>
      db.from('ayudas').delete().eq('publicacion_id', publicacionId).eq('vecino_id', uid!);

  /// Elimina una publicación o servicio (autor o moderador; lo valida RLS).
  Future<void> eliminar(String tabla, String id) async {
    final borradas = await db.from(tabla).delete().eq('id', id).select('id');
    if (borradas.isEmpty) {
      throw const PostgrestException(message: 'row-level security', code: '42501');
    }
  }

  Future<Map<String, dynamic>?> miPerfil() async {
    if (uid == null || forzarOffline) return null;
    final r = await db.rpc('mi_perfil').timeout(const Duration(seconds: 10));
    return r == null ? null : Map<String, dynamic>.from(r as Map);
  }

  // ----------------------------------------------------------- escrituras

  Future<void> _enviar(EntradaPendiente e) => db
      .from(e.tabla)
      .upsert(e.datos, onConflict: 'id', ignoreDuplicates: true)
      .timeout(const Duration(seconds: 12));

  /// Devuelve true si se publicó ya; false si quedó guardada para después.
  Future<bool> publicar(String tabla, Map<String, dynamic> datos) async {
    final e = EntradaPendiente(tabla: tabla, datos: datos);
    if (!forzarOffline) {
      try {
        await _enviar(e);
        return true;
      } catch (err) {
        if (!esErrorDeRed(err)) rethrow;
      }
    }
    pendientes.add(e);
    await _guardarCola();
    return false;
  }

  /// Envía la cola. Devuelve cuántas se enviaron.
  Future<int> sincronizar() async {
    if (forzarOffline || pendientes.isEmpty) return 0;
    var enviados = 0;
    for (final e in List.of(pendientes)) {
      try {
        await _enviar(e);
        pendientes.remove(e);
        enviados++;
      } catch (err) {
        if (esErrorDeRed(err)) break;
        e.error = err is PostgrestException ? err.message : err.toString();
      }
    }
    await _guardarCola();
    return enviados;
  }

  /// Guarda un pedido recibido por QR. false si ya lo tenías.
  Future<bool> agregarDesdeQr(Map<String, dynamic> datos) async {
    if (pendientes.any((p) => p.id == datos['id'])) return false;
    pendientes.add(EntradaPendiente(tabla: 'publicaciones', datos: datos, viaQr: true));
    await _guardarCola();
    return true;
  }

  Future<void> eliminarPendiente(EntradaPendiente e) async {
    pendientes.remove(e);
    await _guardarCola();
  }

  Future<void> darVistoBueno(String servicioId, String? comentario) => db.from('vistos_buenos').insert({
        'servicio_id': servicioId,
        if (comentario != null && comentario.trim().isNotEmpty) 'comentario': comentario.trim(),
      });

  Future<void> cambiarEstado(String id, String estado, {bool atender = false}) =>
      db.from('publicaciones').update({
        'estado': estado,
        if (atender) 'atendido_por': uid,
      }).eq('id', id);

  Future<void> cambiarEmergencia({required bool activa, String? titulo, String? mensaje}) =>
      db.from('emergencia').update({
        'activa': activa,
        'titulo': ?titulo,
        'mensaje': ?mensaje,
        'activada_por': uid,
        'actualizado_en': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', 1);

  Future<void> actualizarPerfil(Map<String, dynamic> cambios) =>
      db.from('perfiles').update(cambios).eq('id', uid!);
}
