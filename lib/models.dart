import 'package:flutter/material.dart';

import 'config.dart';

double? _d(dynamic v) => v == null ? null : (v as num).toDouble();
int _conteo(dynamic x) =>
    x is List && x.isNotEmpty && x.first is Map ? (((x.first as Map)['count'] as num?)?.toInt() ?? 0) : 0;

DateTime _fecha(dynamic v) =>
    (v == null ? null : DateTime.tryParse(v.toString())?.toLocal()) ?? DateTime.now();

/// Módulo 1: oficio, profesión o grupo de apoyo (es_emergencia).
class Servicio {
  Servicio({
    required this.id,
    required this.categoria,
    required this.titulo,
    this.autorId,
    this.autorNombre,
    this.autorRol,
    this.descripcion,
    this.precioRef,
    this.telefono,
    this.horario,
    this.sector,
    this.lat,
    this.lng,
    this.esEmergencia = false,
    this.activo = true,
    this.vistosBuenos = 0,
    this.pendiente = false,
    DateTime? creado,
  }) : creado = creado ?? DateTime.now();

  final String id;
  final String? autorId, autorNombre, autorRol;
  final String categoria, titulo;
  final String? descripcion, precioRef, telefono, horario, sector;
  final double? lat, lng;
  final bool esEmergencia;
  final bool activo;
  final int vistosBuenos;
  final bool pendiente;
  final DateTime creado;

  Punto? get punto => lat != null && lng != null ? Punto(lat!, lng!) : null;

  factory Servicio.fromMap(Map<String, dynamic> m, {bool pendiente = false}) {
    var vb = 0;
    final x = m['vistos_buenos'];
    if (x is List && x.isNotEmpty && x.first is Map) {
      vb = ((x.first as Map)['count'] as num?)?.toInt() ?? 0;
    }
    return Servicio(
      id: m['id'] as String,
      autorId: m['autor_id'] as String?,
      autorNombre: m['autor_nombre'] as String?,
      autorRol: m['autor_rol'] as String?,
      categoria: (m['categoria'] ?? 'otros') as String,
      titulo: (m['titulo'] ?? '') as String,
      descripcion: m['descripcion'] as String?,
      precioRef: m['precio_ref'] as String?,
      telefono: m['telefono'] as String?,
      horario: m['horario'] as String?,
      sector: m['sector'] as String?,
      lat: _d(m['lat']),
      lng: _d(m['lng']),
      esEmergencia: m['es_emergencia'] == true,
      activo: m['activo'] != false,
      vistosBuenos: vb,
      pendiente: pendiente,
      creado: _fecha(m['created_at']),
    );
  }

  Map<String, dynamic> toInsert() => {
        'id': id,
        'categoria': categoria,
        'titulo': titulo,
        'descripcion': descripcion,
        'precio_ref': precioRef,
        'telefono': telefono,
        'horario': horario,
        'sector': sector,
        'lat': lat,
        'lng': lng,
        'es_emergencia': esEmergencia,
        'activo': activo,
      };

  String get textoParaVoz => [
        titulo,
        if (autorNombre != null) 'Ofrecido por $autorNombre',
        if (vistosBuenos > 0) '$vistosBuenos vecinos le dieron su Visto Bueno',
        ?descripcion,
        if (precioRef != null) 'Precio: $precioRef',
        if (horario != null) 'Horario: $horario',
        if (sector != null) 'En $sector',
      ].join('. ');
}

/// Módulo 2: favor, pedido de ayuda o recurso (sin dinero).
class Publicacion {
  Publicacion({
    required this.id,
    required this.tipo,
    required this.categoria,
    required this.titulo,
    this.autorId,
    this.autorNombre,
    this.autorRol,
    this.descripcion,
    this.contactoNombre,
    this.contactoTelefono,
    this.personas,
    this.prioridad = 'normal',
    this.esEmergencia = false,
    this.estado = 'abierta',
    this.atendidoPor,
    this.lat,
    this.lng,
    this.sector,
    this.origen = 'app',
    this.pendiente = false,
    this.ayudantes = 0,
    this.verificada = false,
    this.meta,
    this.avance = 0,
    DateTime? creado,
  }) : creado = creado ?? DateTime.now();

  final int ayudantes; // vecinos que respondieron (ayudo / aporto / me interesa)
  final bool verificada; // verificada por organización o junta vecinal
  final int? meta; // colectas: cuántas donaciones se buscan
  final int avance; // colectas: donaciones ya entregadas en persona

  bool get esColecta => categoria == 'colecta';

  /// Colectas: entregadas en persona + vecinos que se comprometieron.
  int get aportes => avance + ayudantes;
  double get progreso => (meta == null || meta == 0) ? 0 : (aportes / meta!).clamp(0, 1).toDouble();

  /// Estados del reto (pendiente, en atención, atendido, no verificado)
  /// dichos en palabras simples.
  String get estadoTexto => switch (estado) {
        'en_curso' => 'Ya la están ayudando',
        'resuelta' => esPedido ? 'Ya fue atendido' : 'Ya se entregó',
        'no_verificado' => 'Sin confirmar',
        _ => esColecta ? 'Colecta en marcha' : (esPedido ? 'Esperando ayuda' : 'Disponible'),
      };

  /// Qué dice el botón para responder a esta publicación.
  String get textoResponder => esColecta ? 'Yo aporto' : (esPedido ? 'Yo te ayudo' : 'Me interesa');
  final String id;
  final String tipo; // 'pido' | 'ofrezco'
  final String categoria, titulo;
  final String? autorId, autorNombre, autorRol;
  final String? descripcion, contactoNombre, contactoTelefono;
  final int? personas;
  final String prioridad; // normal | alta | critica
  final bool esEmergencia;
  final String estado; // abierta | en_curso | resuelta
  final String? atendidoPor;
  final double? lat, lng;
  final String? sector;
  final String origen; // app | qr | sin_cuenta
  final bool pendiente;
  final DateTime creado;

  bool get esPedido => tipo == 'pido';
  Punto? get punto => lat != null && lng != null ? Punto(lat!, lng!) : null;
  String get autorVisible => autorNombre ?? contactoNombre ?? 'Vecino';

  int get pesoPrioridad => switch (prioridad) { 'critica' => 2, 'alta' => 1, _ => 0 };

  factory Publicacion.fromMap(Map<String, dynamic> m, {bool pendiente = false}) => Publicacion(
        id: m['id'] as String,
        tipo: (m['tipo'] ?? 'pido') as String,
        categoria: (m['categoria'] ?? 'otros') as String,
        titulo: (m['titulo'] ?? '') as String,
        autorId: m['autor_id'] as String?,
        autorNombre: m['autor_nombre'] as String?,
        autorRol: m['autor_rol'] as String?,
        descripcion: m['descripcion'] as String?,
        contactoNombre: m['contacto_nombre'] as String?,
        contactoTelefono: m['contacto_telefono'] as String?,
        personas: (m['personas'] as num?)?.toInt(),
        prioridad: (m['prioridad'] ?? 'normal') as String,
        esEmergencia: m['es_emergencia'] == true,
        estado: (m['estado'] ?? 'abierta') as String,
        atendidoPor: m['atendido_por'] as String?,
        lat: _d(m['lat']),
        lng: _d(m['lng']),
        sector: m['sector'] as String?,
        origen: (m['origen'] ?? 'app') as String,
        pendiente: pendiente,
        ayudantes: _conteo(m['ayudas']),
        verificada: m['verificada'] == true,
        meta: (m['meta'] as num?)?.toInt(),
        avance: (m['avance'] as num?)?.toInt() ?? 0,
        creado: _fecha(m['created_at'] ?? m['creado_offline_en']),
      );

  String get textoParaVoz => [
        if (esEmergencia && prioridad == 'critica') 'Muy urgente',
        esColecta
            ? 'Colecta: $titulo. Llevan $aportes${meta != null ? ' de $meta' : ''}'
            : '${esPedido ? 'Necesita' : 'Ofrece'}: $titulo',
        ?descripcion,
        if (personas != null) 'Para $personas ${personas == 1 ? 'persona' : 'personas'}',
        'Publicado por $autorVisible',
        if (sector != null) 'En $sector',
        if (!esColecta && ayudantes > 0) '$ayudantes ${ayudantes == 1 ? 'vecino respondió' : 'vecinos respondieron'}'
        else if (estado == 'en_curso') 'Ya la están ayudando',
      ].join('. ');
}

class VistoBueno {
  VistoBueno({required this.id, this.autorId, this.autorNombre, this.comentario, this.verificado = false, required this.creado});
  final String id;
  final String? autorId, autorNombre, comentario;
  final bool verificado;
  final DateTime creado;

  factory VistoBueno.fromMap(Map<String, dynamic> m) => VistoBueno(
        id: m['id'] as String,
        autorId: m['autor_id'] as String?,
        autorNombre: m['autor_nombre'] as String?,
        comentario: m['comentario'] as String?,
        verificado: m['autor_verificado'] == true,
        creado: _fecha(m['created_at']),
      );
}

/// Vecino que respondió a una publicación ("Yo te ayudo", "Yo aporto"...).
class Ayuda {
  Ayuda({required this.vecinoId, this.vecinoNombre, this.ayudasConfirmadas = 0, required this.creado});
  final String vecinoId;
  final String? vecinoNombre;
  final int ayudasConfirmadas; // del perfil del vecino, para mostrar su nivel
  final DateTime creado;

  factory Ayuda.fromMap(Map<String, dynamic> m) => Ayuda(
        vecinoId: m['vecino_id'] as String,
        vecinoNombre: m['vecino_nombre'] as String?,
        ayudasConfirmadas: ((m['perfiles'] as Map?)?['ayudas_confirmadas'] as num?)?.toInt() ?? 0,
        creado: _fecha(m['created_at']),
      );
}

/// Reconocimiento vecinal según ayudas CONFIRMADAS por quien fue ayudado.
class Nivel {
  const Nivel(this.nombre, this.emoji, this.minimo, this.descripcion);
  final String nombre, emoji, descripcion;
  final int minimo;

  static const todos = [
    Nivel('Vecino nuevo', '🏠', 0, 'Tu primera ayuda confirmada te da tu primer reconocimiento.'),
    Nivel('Buen vecino', '🌱', 1, 'Ya ayudaste a alguien del barrio.'),
    Nivel('Vecino solidario', '🤝', 3, 'Tus vecinos saben que pueden contar contigo.'),
    Nivel('Corazón del barrio', '💛', 7, 'Eres parte de lo que mantiene unido al barrio.'),
    Nivel('Guardián del barrio', '🛡️', 15, 'Un ejemplo para toda la comunidad.'),
  ];

  static Nivel de(int ayudas) => todos.lastWhere((n) => ayudas >= n.minimo);

  static Nivel? siguiente(int ayudas) {
    for (final n in todos) {
      if (n.minimo > ayudas) return n;
    }
    return null;
  }
}

/// Una entrada del historial del vecino.
class EntradaHistorial {
  EntradaHistorial({required this.tipo, required this.titulo, required this.fecha, this.detalle, this.publicacion});
  final String tipo; // 'respondi' | 'agradecimiento' | 'visto_bueno' | 'publique'
  final String titulo;
  final String? detalle;
  final DateTime fecha;
  final Publicacion? publicacion;
}

class EstadoEmergencia {
  const EstadoEmergencia({required this.activa, this.titulo, this.mensaje});
  const EstadoEmergencia.inactiva() : this(activa: false);
  final bool activa;
  final String? titulo, mensaje;

  factory EstadoEmergencia.fromMap(Map<String, dynamic> m) => EstadoEmergencia(
        activa: m['activa'] == true,
        titulo: m['titulo'] as String?,
        mensaje: m['mensaje'] as String?,
      );
}

/// Solicitud o pedido de un vecino a un servicio, producto o clase publicado.
class PedidoServicio {
  PedidoServicio({
    required this.id,
    required this.servicioId,
    required this.prestadorId,
    this.clienteId,
    required this.clienteNombre,
    this.clienteTelefono,
    this.clienteSector,
    required this.detalle,
    this.fechaDeseada,
    this.estado = 'pendiente',
    DateTime? creado,
    this.servicioTitulo,
  }) : creado = creado ?? DateTime.now();

  final String id;
  final String servicioId;
  final String prestadorId;
  final String? clienteId;
  final String clienteNombre;
  final String? clienteTelefono;
  final String? clienteSector;
  final String detalle;
  final String? fechaDeseada;
  final String estado; // 'pendiente' | 'aceptado' | 'en_proceso' | 'completado' | 'cancelado'
  final DateTime creado;
  final String? servicioTitulo;

  bool get esPendiente => estado == 'pendiente';
  bool get esAceptado => estado == 'aceptado';
  bool get esEnProceso => estado == 'en_proceso';
  bool get esCompletado => estado == 'completado';
  bool get esCancelado => estado == 'cancelado';

  String get estadoLegible => switch (estado) {
        'aceptado' => 'Aceptado',
        'en_proceso' => 'En camino / proceso',
        'completado' => 'Completado',
        'cancelado' => 'Cancelado',
        _ => 'Pendiente',
      };

  (Color, Color) get coloresEstado => switch (estado) {
        'aceptado' => (const Color(0xFF1565C0), const Color(0xFFE3F2FD)),
        'en_proceso' => (const Color(0xFFE65100), const Color(0xFFFFF3E0)),
        'completado' => (const Color(0xFF2E7D32), const Color(0xFFE8F5E9)),
        'cancelado' => (const Color(0xFF757575), const Color(0xFFEEEEEE)),
        _ => (const Color(0xFFC2185B), const Color(0xFFFCE4EC)),
      };

  factory PedidoServicio.fromMap(Map<String, dynamic> m) {
    String? titulo;
    if (m['servicios'] is Map) {
      titulo = (m['servicios'] as Map)['titulo'] as String?;
    }
    return PedidoServicio(
      id: m['id'] as String,
      servicioId: m['servicio_id'] as String,
      prestadorId: m['prestador_id'] as String,
      clienteId: m['cliente_id'] as String?,
      clienteNombre: (m['cliente_nombre'] ?? 'Vecino') as String,
      clienteTelefono: m['cliente_telefono'] as String?,
      clienteSector: m['cliente_sector'] as String?,
      detalle: (m['detalle'] ?? '') as String,
      fechaDeseada: m['fecha_deseada'] as String?,
      estado: (m['estado'] ?? 'pendiente') as String,
      creado: _fecha(m['created_at']),
      servicioTitulo: titulo,
    );
  }

  Map<String, dynamic> toInsert() => {
        'id': id,
        'servicio_id': servicioId,
        'prestador_id': prestadorId,
        if (clienteId != null) 'cliente_id': clienteId,
        'cliente_nombre': clienteNombre,
        'cliente_telefono': clienteTelefono,
        'cliente_sector': clienteSector,
        'detalle': detalle,
        if (fechaDeseada != null && fechaDeseada!.trim().isNotEmpty) 'fecha_deseada': fechaDeseada!.trim(),
        'estado': estado,
      };
}


// ==================================================== Módulo 4 · Foro Vecinal

/// Tipos de publicaciones en el foro vecinal.
enum TipoPublicacionForo { servicio, dialogo, recomendacion, aviso }

/// Publicación o consulta en el foro vecinal.
class TemaForo {
  TemaForo({
    required this.id,
    this.autorId,
    required this.tipo,
    required this.titulo,
    required this.contenido,
    required this.autorNombre,
    this.autorRol = 'vecino',
    this.esPrestador = false,
    this.autorOficio,
    required this.sector,
    this.categoriaServicio,
    this.lat,
    this.lng,
    this.apoyos = 0,
    this.apoyadoPorUsuario = false,
    this.respuestasCount = 0,
    this.estado = 'abierto',
    required this.creado,
  });

  final String id;
  final String? autorId;
  final TipoPublicacionForo tipo;
  final String titulo;
  final String contenido;
  final String autorNombre;
  final String autorRol;
  final bool esPrestador;
  final String? autorOficio;
  final String sector;
  final String? categoriaServicio;
  final double? lat;
  final double? lng;
  int apoyos;
  bool apoyadoPorUsuario;
  int respuestasCount;
  String estado; // 'abierto', 'resuelto', 'cerrado'
  final DateTime creado;

  String get tiempoRelativo {
    final diff = DateTime.now().difference(creado);
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes.clamp(1, 59);
      return 'Hace $m min';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return 'Hace $h ${h == 1 ? 'hora' : 'horas'}';
    }
    final d = diff.inDays;
    return 'Hace $d ${d == 1 ? 'día' : 'días'}';
  }

  (String, IconData, Color, Color) get datosTipo => switch (tipo) {
        TipoPublicacionForo.servicio => (
            'Busca servicio',
            Icons.handyman_rounded,
            const Color(0xFF0284C7),
            const Color(0xFFE0F2FE),
          ),
        TipoPublicacionForo.recomendacion => (
            'Recomendación',
            Icons.verified_rounded,
            const Color(0xFFD97706),
            const Color(0xFFFEF3C7),
          ),
        TipoPublicacionForo.aviso => (
            'Aviso vecinal',
            Icons.campaign_rounded,
            const Color(0xFF7C3AED),
            const Color(0xFFF3E8FF),
          ),
        TipoPublicacionForo.dialogo => (
            'Comunidad',
            Icons.forum_rounded,
            const Color(0xFF059669),
            const Color(0xFFD1FAE5),
          ),
      };

  factory TemaForo.fromMap(Map<String, dynamic> m, {String? miUid}) {
    final tipoStr = (m['tipo'] ?? 'dialogo') as String;
    final t = switch (tipoStr) {
      'servicio' => TipoPublicacionForo.servicio,
      'recomendacion' => TipoPublicacionForo.recomendacion,
      'aviso' => TipoPublicacionForo.aviso,
      _ => TipoPublicacionForo.dialogo,
    };

    var apoyado = false;
    final apoyos = m['foro_apoyos'];
    if (miUid != null && apoyos is List) {
      apoyado = apoyos.any((a) => a is Map && a['usuario_id'] == miUid);
    }

    return TemaForo(
      id: m['id'] as String,
      autorId: m['autor_id'] as String?,
      tipo: t,
      titulo: (m['titulo'] ?? '') as String,
      contenido: (m['contenido'] ?? '') as String,
      autorNombre: (m['autor_nombre'] ?? 'Vecino') as String,
      autorRol: (m['autor_rol'] ?? 'vecino') as String,
      esPrestador: m['es_prestador'] == true,
      autorOficio: m['autor_oficio'] as String?,
      sector: (m['sector'] ?? 'Chimbote') as String,
      categoriaServicio: m['categoria_servicio'] as String?,
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      apoyos: (m['apoyos_count'] as num?)?.toInt() ?? 0,
      apoyadoPorUsuario: apoyado,
      respuestasCount: (m['respuestas_count'] as num?)?.toInt() ?? 0,
      estado: (m['estado'] ?? 'abierto') as String,
      creado: DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

/// Respuesta o comentario a un tema del foro vecinal.
class RespuestaForo {
  RespuestaForo({
    required this.id,
    required this.temaId,
    this.autorId,
    required this.contenido,
    required this.autorNombre,
    this.autorRol = 'vecino',
    this.esPrestador = false,
    this.autorOficio,
    this.sector,
    this.contactoTelefono,
    this.nombreComercial,
    this.servicioId,
    this.vistosBuenos = 0,
    required this.creado,
  });

  final String id;
  final String temaId;
  final String? autorId;
  final String contenido;
  final String autorNombre;
  final String autorRol;
  final bool esPrestador;
  final String? autorOficio;
  final String? sector;
  final String? contactoTelefono;
  final String? nombreComercial;
  final String? servicioId;
  final int vistosBuenos;
  final DateTime creado;

  String get tiempoRelativo {
    final diff = DateTime.now().difference(creado);
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes.clamp(1, 59);
      return 'Hace $m min';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return 'Hace $h ${h == 1 ? 'hora' : 'horas'}';
    }
    final d = diff.inDays;
    return 'Hace $d ${d == 1 ? 'día' : 'días'}';
  }

  factory RespuestaForo.fromMap(Map<String, dynamic> m) {
    return RespuestaForo(
      id: m['id'] as String,
      temaId: m['tema_id'] as String,
      autorId: m['autor_id'] as String?,
      contenido: (m['contenido'] ?? '') as String,
      autorNombre: (m['autor_nombre'] ?? 'Vecino') as String,
      autorRol: (m['autor_rol'] ?? 'vecino') as String,
      esPrestador: m['es_prestador'] == true,
      autorOficio: m['autor_oficio'] as String?,
      sector: m['sector'] as String?,
      contactoTelefono: m['contacto_telefono'] as String?,
      nombreComercial: m['nombre_comercial'] as String?,
      servicioId: m['servicio_id'] as String?,
      vistosBuenos: (m['vistos_buenos'] as num?)?.toInt() ?? 0,
      creado: DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}
