import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import '../state/app_state.dart' show SinPermiso;
import 'datos_iniciales.dart';

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
    // Primer uso sin internet: datos incluidos en la app (grupos de apoyo).
    if (raw == null) return DatosIniciales.actual.respaldo(clave) ?? [];
    return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ------------------------------------------------------------ lecturas

  /// Pulso del barrio: SOLO casos de éxito de las últimas [horas], sin nombres:
  ///   - recomendaciones (Visto Bueno) a servicios y productos,
  ///   - ayudas agradecidas (alguien recibió ayuda y lo confirmó),
  ///   - pedidos y SOS atendidos.
  /// Sin internet devuelve la última copia y cuándo se actualizó.
  Future<({List<Map<String, dynamic>> recomendaciones, List<Map<String, dynamic>> agradecimientos, List<Map<String, dynamic>> atendidos, Set<String> brigadistas, DateTime? actualizado, bool enVivo})>
      pulso({int horas = 48}) async {
    final desde = DateTime.now().toUtc().subtract(Duration(hours: horas)).toIso8601String();
    var enVivo = false;
    Future<List<Map<String, dynamic>>> q(String clave, Future<List<Map<String, dynamic>>> Function() c) async {
      if (!forzarOffline) {
        try {
          final r = await c().timeout(const Duration(seconds: 10));
          await prefs.setString('cache_$clave', jsonEncode(r));
          enVivo = true;
          return r;
        } catch (e) {
          if (!esErrorDeRed(e)) rethrow;
        }
      }
      final raw = prefs.getString('cache_$clave');
      if (raw == null) return [];
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    final recomendaciones = await q(
      'pulso_recomendaciones',
      () => db
          .from('vistos_buenos')
          .select('created_at, autor:perfiles(sector), servicios(titulo, categoria, sector)')
          .gte('created_at', desde)
          .order('created_at', ascending: false)
          .limit(15),
    );
    final agradecimientos = await q(
      'pulso_agradecimientos',
      () => db
          .from('agradecimientos')
          .select('created_at, publicaciones(categoria, sector, origen, es_emergencia)')
          .gte('created_at', desde)
          .order('created_at', ascending: false)
          .limit(15),
    );
    final atendidos = await q(
      'pulso_atendidos',
      () => db
          .from('publicaciones')
          .select('categoria, sector, origen, es_emergencia, tipo, created_at, atendido_por, atendio:perfiles!publicaciones_atendido_por_fkey(rol)')
          .eq('estado', 'resuelta')
          .eq('tipo', 'pido')
          .gte('created_at', desde)
          .order('created_at', ascending: false)
          .limit(15),
    );
    // Para decir quién atendió un SOS: "un brigadista".
    final brigadistas = await q(
      'pulso_brigadistas',
      () => db.from('brigadistas').select('vecino_id').eq('estado', 'activo').limit(500),
    );
    if (enVivo) await prefs.setString('pulso_actualizado', DateTime.now().toIso8601String());
    final at = prefs.getString('pulso_actualizado');
    return (
      recomendaciones: recomendaciones,
      agradecimientos: agradecimientos,
      atendidos: atendidos,
      brigadistas: {for (final b in brigadistas) b['vecino_id'] as String},
      actualizado: at == null ? null : DateTime.tryParse(at),
      enVivo: enVivo,
    );
  }

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
    Future<List<Map<String, dynamic>>> consulta(String campos) => db
        .from('publicaciones')
        .select(campos)
        .eq('es_emergencia', emergencia)
        .neq('estado', 'resuelta')
        .order('created_at', ascending: false)
        .limit(300);
    final filas = await _consultar('publicaciones_$emergencia', () async {
      try {
        // Con la foto de perfil de quien publica (migración 0010_foto_perfil).
        return await consulta('*, ayudas(count), autor:perfiles!publicaciones_autor_id_fkey(foto_url)');
      } on PostgrestException {
        return consulta('*, ayudas(count)'); // sin la columna de foto: igual funciona
      }
    });
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

  /// Cuánto tiempo sigue visible una alerta SOS sin atender: así no quedan
  /// alertas abiertas para siempre ("continuas").
  static Duration vigenciaSos(String prioridad) =>
      prioridad == 'critica' ? const Duration(hours: 24) : const Duration(hours: 6);

  /// Alertas SOS vigentes y sin atender. Se muestran SIEMPRE, aunque la
  /// junta no haya activado el modo emergencia. Las marcadas "sin confirmar"
  /// (3 reportes de vecinos o una organización) salen de la lista.
  Future<List<Publicacion>> alertasSos() async {
    final desde = DateTime.now().toUtc().subtract(const Duration(hours: 24)).toIso8601String();
    final filas = await _consultar(
      'alertas_sos',
      () => db
          .from('publicaciones')
          .select('*, ayudas(count)')
          .eq('origen', 'sos')
          .not('estado', 'in', '(resuelta,no_verificado)')
          .gte('created_at', desde)
          .order('created_at', ascending: false)
          .limit(30),
    );
    final ahora = DateTime.now();
    final enviadas = filas
        .map(Publicacion.fromMap)
        .where((p) => ahora.difference(p.creado) <= vigenciaSos(p.prioridad))
        .toList();
    final ids = enviadas.map((p) => p.id).toSet();
    return [
      ...pendientes
          .where((p) => p.tabla == 'publicaciones' && p.datos['origen'] == 'sos' && !ids.contains(p.id))
          .map((p) => Publicacion.fromMap(p.datos, pendiente: true)),
      ...enviadas,
    ]..sort((a, b) {
        final x = b.pesoPrioridad.compareTo(a.pesoPrioridad);
        return x != 0 ? x : b.creado.compareTo(a.creado);
      });
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
          .select('vecino_id, vecino_nombre, created_at, perfiles(ayudas_confirmadas)')
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

  /// Pedidos recibidos por el usuario para sus servicios/productos/clases.
  Future<List<PedidoServicio>> pedidosRecibidos() async {
    final id = uid;
    if (id == null) return [];
    final filas = await _consultar(
      'pedidos_recibidos_$id',
      () => db
          .from('pedidos_servicio')
          .select('*, servicios(titulo)')
          .eq('prestador_id', id)
          .order('created_at', ascending: false),
    );
    return filas.map(PedidoServicio.fromMap).toList();
  }

  /// Todos los servicios creados por el usuario (activos y en pausa).
  Future<List<Servicio>> misServicios() async {
    final id = uid;
    if (id == null) return [];
    final filas = await _consultar(
      'mis_servs_$id',
      () => db
          .from('servicios')
          .select('*, vistos_buenos(count)')
          .eq('autor_id', id)
          .order('created_at', ascending: false),
    );
    return filas.map(Servicio.fromMap).toList();
  }

  // -------------------------------------------------------- foro vecinal

  Future<List<Map<String, dynamic>>> temasForo() async {
    try {
      return await _consultar(
        'foro_temas',
        () => db
            .from('foro_temas')
            .select('*, foro_apoyos(usuario_id, tipo)')
            .order('created_at', ascending: false)
            .limit(200),
      );
    } on PostgrestException catch (e) {
      if (e.code == '42P01') return [];
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> respuestasForo(String temaId) async {
    try {
      try {
        return await _consultar(
          'foro_respuestas_$temaId',
          () => db
              .from('foro_respuestas')
              .select('*, foro_respuestas_likes(usuario_id, tipo)')
              .eq('tema_id', temaId)
              .order('created_at', ascending: true)
              .limit(300),
        );
      } catch (_) {
        return await _consultar(
          'foro_respuestas_$temaId',
          () => db
              .from('foro_respuestas')
              .select()
              .eq('tema_id', temaId)
              .order('created_at', ascending: true)
              .limit(300),
        );
      }
    } on PostgrestException catch (e) {
      if (e.code == '42P01') return [];
      rethrow;
    }
  }

  Future<void> toggleReaccionRespuestaForo(String respuestaId, {required String tipo, required bool activar}) async {
    final u = uid;
    if (u == null) return;
    try {
      if (activar) {
        try {
          await db.from('foro_respuestas_likes').upsert({
            'respuesta_id': respuestaId,
            'usuario_id': u,
            'tipo': tipo,
          });
        } catch (_) {
          await db.from('foro_respuestas_likes').upsert({
            'respuesta_id': respuestaId,
            'usuario_id': u,
          });
        }
      } else {
        await db.from('foro_respuestas_likes').delete().eq('respuesta_id', respuestaId).eq('usuario_id', u);
      }
    } catch (_) {}
  }

  Future<void> toggleLikeRespuesta(String respuestaId, bool darLike) async {
    await toggleReaccionRespuestaForo(respuestaId, tipo: 'like', activar: darLike);
  }

  Future<void> crearTemaForo(Map<String, dynamic> datos) async {
    await db.from('foro_temas').insert(datos);
  }

  Future<void> crearRespuestaForo(Map<String, dynamic> datos) async {
    await db.from('foro_respuestas').insert(datos);
  }

  Future<void> toggleReaccionTemaForo(String temaId, {required String tipo, required bool activar}) async {
    final u = uid;
    if (u == null) return;
    try {
      if (activar) {
        try {
          await db.from('foro_apoyos').upsert({
            'tema_id': temaId,
            'usuario_id': u,
            'tipo': tipo,
          });
        } catch (_) {
          await db.from('foro_apoyos').upsert({
            'tema_id': temaId,
            'usuario_id': u,
          });
        }
      } else {
        await db.from('foro_apoyos').delete().eq('tema_id', temaId).eq('usuario_id', u);
      }
    } catch (_) {}
  }

  Future<void> toggleApoyoForo(String temaId, bool apoyar) async {
    await toggleReaccionTemaForo(temaId, tipo: 'like', activar: apoyar);
  }

  Future<void> eliminarTemaForo(String id) async {
    await db.from('foro_temas').delete().eq('id', id);
  }

  Future<void> cambiarEstadoTemaForo(String id, String estado) async {
    await db.from('foro_temas').update({'estado': estado}).eq('id', id);
  }

  Future<void> eliminarRespuestaForo(String id) async {
    await db.from('foro_respuestas').delete().eq('id', id);
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

  // ------------------------------------------------ reconocimiento vecinal

  /// "¡Ya me ayudaron!": el autor confirma quién lo ayudó.
  Future<void> agradecer(String publicacionId, List<String> vecinos, {String? mensaje}) async {
    if (vecinos.isEmpty) return;
    await db.from('agradecimientos').upsert([
      for (final v in vecinos)
        {
          'publicacion_id': publicacionId,
          'para_id': v,
          if (mensaje != null && mensaje.trim().isNotEmpty) 'mensaje': mensaje.trim(),
        },
    ], onConflict: 'publicacion_id,para_id', ignoreDuplicates: true);
  }

  /// Historial del vecino: a quién respondió, agradecimientos recibidos,
  /// Vistos Buenos que dio y lo que publicó.
  Future<List<EntradaHistorial>> historial() async {
    final id = uid;
    if (id == null) return [];
    final respuestas = await _consultar(
      'hist_resp_$id',
      () => db
          .from('ayudas')
          .select('created_at, publicaciones(*)')
          .eq('vecino_id', id)
          .order('created_at', ascending: false)
          .limit(100),
    );
    final gracias = await _consultar(
      'hist_gracias_$id',
      () => db
          .from('agradecimientos')
          .select('created_at, de_nombre, titulo, mensaje')
          .eq('para_id', id)
          .order('created_at', ascending: false)
          .limit(100),
    );
    final vbs = await _consultar(
      'hist_vb_$id',
      () => db
          .from('vistos_buenos')
          .select('created_at, comentario, servicios(titulo)')
          .eq('autor_id', id)
          .order('created_at', ascending: false)
          .limit(100),
    );
    final lista = <EntradaHistorial>[
      for (final r in respuestas)
        if (r['publicaciones'] is Map)
          () {
            final p = Publicacion.fromMap(Map<String, dynamic>.from(r['publicaciones'] as Map));
            return EntradaHistorial(
              tipo: 'respondi',
              titulo: p.titulo,
              detalle: p.esColecta
                  ? 'Aportaste a la colecta de ${p.autorVisible}'
                  : (p.esPedido ? 'Ofreciste ayuda a ${p.autorVisible}' : 'Te interesó lo que ofreció ${p.autorVisible}'),
              fecha: DateTime.tryParse(r['created_at'].toString())?.toLocal() ?? DateTime.now(),
              publicacion: p,
            );
          }(),
      for (final g in gracias)
        EntradaHistorial(
          tipo: 'agradecimiento',
          titulo: '${g['de_nombre'] ?? 'Un vecino'} te agradeció',
          detalle: [g['titulo'], if (g['mensaje'] != null) '"${g['mensaje']}"'].whereType<String>().join(' · '),
          fecha: DateTime.tryParse(g['created_at'].toString())?.toLocal() ?? DateTime.now(),
        ),
      for (final v in vbs)
        EntradaHistorial(
          tipo: 'visto_bueno',
          titulo: 'Diste tu Visto Bueno',
          detalle: [((v['servicios'] as Map?)?['titulo']), v['comentario']].whereType<String>().join(' · '),
          fecha: DateTime.tryParse(v['created_at'].toString())?.toLocal() ?? DateTime.now(),
        ),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista;
  }

  /// Vecinos con más ayudas confirmadas (reconocimiento público).
  Future<List<Map<String, dynamic>>> vecinosDestacados() => _consultar(
        'destacados',
        () => db
            .from('perfiles')
            .select('id, nombre, sector, ayudas_confirmadas')
            .gt('ayudas_confirmadas', 0)
            .order('ayudas_confirmadas', ascending: false)
            .limit(5),
      );

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

  // --------------------------------------------------- junta y brigadistas

  /// Mi nombramiento como brigadista (invitado o activo), si existe.
  Future<Brigadista?> miNombramiento() async {
    if (uid == null) return null;
    final r = await _consultar(
      'mi_brigadista',
      () => db.from('brigadistas').select().eq('vecino_id', uid!).limit(1),
    );
    return r.isEmpty ? null : Brigadista.fromMap(r.first);
  }

  /// Vecinos registrados en un sector (para el panel de la junta).
  Future<List<MiembroSector>> miembrosSector(String sector) async {
    final r = await _consultar(
      'miembros_$sector',
      () => db
          .from('perfiles')
          .select('id, nombre, verificado_gps, ayudas_confirmadas')
          .eq('sector', sector)
          .eq('rol', 'vecino')
          .order('nombre')
          .limit(500),
    );
    return r.map(MiembroSector.fromMap).toList();
  }

  Future<List<Brigadista>> brigadistasSector(String sector) async {
    final r = await _consultar(
      'brigadistas_$sector',
      () => db.from('brigadistas').select('*, perfiles!brigadistas_vecino_id_fkey(nombre)').eq('sector', sector),
    );
    return r.map(Brigadista.fromMap).toList();
  }

  Future<void> nombrarBrigadista({required String vecinoId, required String sector, required String especialidad}) =>
      db.from('brigadistas').insert({'vecino_id': vecinoId, 'sector': sector, 'especialidad': especialidad, 'estado': 'invitado'});

  /// La junta quita a un brigadista, o el propio vecino renuncia / dice "Ahora no".
  Future<void> quitarBrigadista(String vecinoId) => db.from('brigadistas').delete().eq('vecino_id', vecinoId);

  Future<void> aceptarNombramiento() => db
      .from('brigadistas')
      .update({'estado': 'activo', 'aceptado_en': DateTime.now().toUtc().toIso8601String()}).eq('vecino_id', uid!);

  Future<List<CanalSector>> canalesSector(String sector) async {
    final r = await _consultar(
      'canales_$sector',
      () => db.from('canales_sector').select().eq('sector', sector).order('created_at'),
    );
    return r.map(CanalSector.fromMap).toList();
  }

  Future<void> guardarCanal(CanalSector c) => db.from('canales_sector').insert(c.toInsert());

  Future<void> borrarCanal(String id) => db.from('canales_sector').delete().eq('id', id);

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

  /// Envía la cola. Devuelve cuántas se enviaron y cuáles fueron RECHAZADAS
  /// por primera vez (permiso, límite anti-spam...), para avisar a la persona
  /// en lugar de dejarlas en silencio como "guardadas".
  Future<(int, List<EntradaPendiente>)> sincronizar() async {
    if (forzarOffline || pendientes.isEmpty) return (0, <EntradaPendiente>[]);
    var enviados = 0;
    final rechazadas = <EntradaPendiente>[];
    for (final e in List.of(pendientes)) {
      try {
        await _enviar(e);
        pendientes.remove(e);
        enviados++;
      } catch (err) {
        if (esErrorDeRed(err)) break;
        if (e.error == null) rechazadas.add(e);
        e.error = err is PostgrestException ? err.message : err.toString();
      }
    }
    await _guardarCola();
    return (enviados, rechazadas);
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

  /// SOS para el panel de coordinación: todos los de los últimos [dias] días
  /// (también atendidos o falsas alarmas), del más reciente al más antiguo.
  Future<List<Publicacion>> sosParaCoordinar({int dias = 7}) async {
    final desde = DateTime.now().toUtc().subtract(Duration(days: dias)).toIso8601String();
    final filas = await _consultar(
      'sos_coordinar',
      () => db
          .from('publicaciones')
          .select('*, ayudas(count)')
          // SOS del botón rojo y "Necesito ayuda" de emergencia: los dos piden auxilio.
          .or('origen.eq.sos,and(es_emergencia.eq.true,tipo.eq.pido)')
          .gte('created_at', desde)
          .order('created_at', ascending: false)
          .limit(150),
    );
    return filas.map(Publicacion.fromMap).toList();
  }

  /// La junta asigna un SOS a un brigadista: queda "en atención" a su nombre.
  Future<void> asignarSos(String id, String brigadistaId) =>
      db.from('publicaciones').update({'estado': 'en_curso', 'atendido_por': brigadistaId}).eq('id', id);

  Future<void> cambiarEstado(String id, String estado, {bool atender = false}) =>
      db.from('publicaciones').update({
        'estado': estado,
        if (atender) 'atendido_por': uid,
      }).eq('id', id);

  // ------------------------------------------------- "Estoy bien" (0012)

  /// Mi estado en esta emergencia: 'bien', 'ayuda' o null si no respondí.
  Future<String?> miEstado(String emergencia) async {
    if (uid == null || forzarOffline) return null;
    final r = await db
        .from('estados_vecino')
        .select('estado')
        .eq('vecino_id', uid!)
        .eq('emergencia_desde', emergencia)
        .maybeSingle()
        .timeout(const Duration(seconds: 10));
    return r?['estado'] as String?;
  }

  Future<void> marcarEstado({required String emergencia, required String estado, String? sector}) => db
      .from('estados_vecino')
      .upsert({
        'vecino_id': uid,
        'emergencia_desde': emergencia,
        'estado': estado,
        'sector': sector,
        'actualizado_en': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'vecino_id,emergencia_desde')
      .timeout(const Duration(seconds: 10));

  /// Quiénes avisaron que están bien y quiénes que necesitan ayuda.
  Future<({Set<String> bien, Set<String> ayuda})> resumenEstados(String emergencia) async {
    final r = await _consultar(
      'estados_$emergencia',
      () => db.from('estados_vecino').select('vecino_id, estado').eq('emergencia_desde', emergencia).limit(5000),
    );
    return (
      bien: {for (final f in r) if (f['estado'] == 'bien') f['vecino_id'] as String},
      ayuda: {for (final f in r) if (f['estado'] != 'bien') f['vecino_id'] as String},
    );
  }

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

  /// Sube la foto de perfil a Storage (bucket "avatares", carpeta propia) y
  /// guarda su URL en el perfil. Devuelve la URL nueva.
  Future<String> subirFotoPerfil(Uint8List bytes, String tipo) async {
    final ruta = '$uid/avatar';
    await db.storage.from('avatares').uploadBinary(
          ruta,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: tipo, cacheControl: '3600'),
        ).timeout(const Duration(seconds: 30));
    // "?v=" evita que el celular muestre la foto anterior guardada en caché.
    final url = '${db.storage.from('avatares').getPublicUrl(ruta)}?v=${DateTime.now().millisecondsSinceEpoch}';
    await actualizarPerfil({'foto_url': url});
    return url;
  }

  // ------------------------------------------- recuperar la clave (0015)

  /// Código nuevo de recuperación para la cuenta con sesión (anula el anterior).
  Future<String> crearCodigoRecuperacion() async =>
      (await db.rpc('crear_codigo_recuperacion').timeout(const Duration(seconds: 15))) as String;

  /// Cambia la clave con el código. Devuelve el código NUEVO si salió bien;
  /// si no, lanza [SinPermiso] con el motivo para mostrarlo tal cual.
  Future<String> recuperarClave({required String email, required String codigo, required String nueva}) async {
    final r = await db.rpc('recuperar_clave', params: {'p_email': email, 'p_codigo': codigo, 'p_nueva': nueva})
        .timeout(const Duration(seconds: 15));
    final m = Map<String, dynamic>.from(r as Map);
    if (m['ok'] == true) return m['codigo'] as String;
    throw SinPermiso((m['mensaje'] as String?) ?? 'No se pudo cambiar la clave.');
  }

  /// La junta vecinal genera un código para un vecino que perdió el suyo.
  Future<String> codigoParaVecino(String celular) async =>
      (await db.rpc('codigo_para_vecino', params: {'p_celular': celular}).timeout(const Duration(seconds: 15))) as String;

  Future<void> quitarFotoPerfil() async {
    try {
      await db.storage.from('avatares').remove(['$uid/avatar']);
    } catch (_) {
      // Si el archivo ya no estaba, igual se quita del perfil.
    }
    await actualizarPerfil({'foto_url': null});
  }

  Future<void> crearPedidoServicio(Map<String, dynamic> datos) =>
      db.from('pedidos_servicio').insert(datos);

  Future<void> cambiarEstadoPedido(String id, String estado) =>
      db.from('pedidos_servicio').update({'estado': estado}).eq('id', id);

  Future<void> actualizarServicio(String id, Map<String, dynamic> cambios) =>
      db.from('servicios').update(cambios).eq('id', id);

  Future<void> alternarActivoServicio(String id, bool activo) =>
      db.from('servicios').update({'activo': activo}).eq('id', id);
}
