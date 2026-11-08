import 'package:flutter/material.dart';

import 'config.dart';
import 'ui/tema.dart';

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
    this.verificadosPorSector = const {},
    this.motivos = const {},
    this.respondiendoA,
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

  /// Vistos Buenos de vecinos VERIFICADOS, contados por su sector.
  final Map<String, int> verificadosPorSector;

  /// Cuántas veces se eligió cada motivo ("puntual", "precio_justo"...).
  final Map<String, int> motivos;
  final String? respondiendoA;
  final bool pendiente;
  final DateTime creado;

  Punto? get punto => lat != null && lng != null ? Punto(lat!, lng!) : null;

  /// Recomendaciones de vecinos verificados de [sector] (si no se sabe el
  /// sector de quien mira, se usa el del propio servicio).
  int recomendacionesDeZona(String? sector) => verificadosPorSector[sector ?? this.sector] ?? 0;

  /// Sello "Recomendado en tu barrio": 3 o más vecinos verificados de la zona.
  static const minimoSello = 3;
  bool tieneSello(String? sector) => recomendacionesDeZona(sector) >= minimoSello;

  /// Los [n] motivos más elegidos (al menos 1 vez), del más al menos.
  List<String> motivosPrincipales([int n = 2]) {
    final l = motivos.entries.where((e) => e.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in l.take(n)) e.key];
  }

  factory Servicio.fromMap(Map<String, dynamic> m, {bool pendiente = false}) {
    var vb = 0;
    final porSector = <String, int>{};
    final motivos = <String, int>{};
    final x = m['vistos_buenos'];
    if (x is List && x.isNotEmpty && x.first is Map && (x.first as Map).containsKey('count')) {
      vb = ((x.first as Map)['count'] as num?)?.toInt() ?? 0;
    } else if (x is List) {
      // Lista de Vistos Buenos con sector, verificación y motivos (0016).
      vb = x.length;
      for (final f in x.whereType<Map>()) {
        final sec = f['autor_sector'] as String?;
        if (f['autor_verificado'] == true && sec != null) porSector[sec] = (porSector[sec] ?? 0) + 1;
        for (final mo in (f['motivos'] as List?) ?? const []) {
          motivos['$mo'] = (motivos['$mo'] ?? 0) + 1;
        }
      }
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
      verificadosPorSector: porSector,
      motivos: motivos,
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

  /// Urgencia de una petición del día a día (2 niveles: urgente / puede
  /// esperar). Una petición urgente deja de serlo a las 24 h, para que no se
  /// quede arriba para siempre.
  bool get esUrgente =>
      prioridad != 'normal' && DateTime.now().difference(creado) < const Duration(hours: 24);

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

/// Motivos de un toque al dar el Visto Bueno: (id, texto, ícono).
const motivosVistoBueno = <(String, String, IconData)>[
  ('puntual', 'Puntual', Icons.schedule),
  ('precio_justo', 'Precio justo', Icons.payments_outlined),
  ('buen_trabajo', 'Buen trabajo', Icons.handyman_outlined),
  ('amable', 'Amable', Icons.sentiment_satisfied_alt),
  ('confiable', 'De confianza', Icons.verified_user_outlined),
];

String textoMotivo(String id) => motivosVistoBueno.firstWhere((m) => m.$1 == id, orElse: () => (id, id, Icons.check)).$2;

class VistoBueno {
  VistoBueno({
    required this.id,
    this.autorId,
    this.autorNombre,
    this.comentario,
    this.verificado = false,
    this.sector,
    this.motivos = const [],
    required this.creado,
  });
  final String id;
  final String? autorId, autorNombre, comentario, sector;
  final bool verificado;
  final List<String> motivos;
  final DateTime creado;

  factory VistoBueno.fromMap(Map<String, dynamic> m) => VistoBueno(
        id: m['id'] as String,
        autorId: m['autor_id'] as String?,
        autorNombre: m['autor_nombre'] as String?,
        comentario: m['comentario'] as String?,
        verificado: m['autor_verificado'] == true,
        sector: m['autor_sector'] as String?,
        motivos: [for (final x in (m['motivos'] as List?) ?? const []) '$x'],
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
  const Nivel(this.nombre, this.corto, this.icono, this.color, this.minimo, this.descripcion);
  final String nombre, corto, descripcion;
  final IconData icono;
  final Color color;
  final int minimo;

  static const todos = [
    Nivel('Vecino nuevo', 'Nuevo', Icons.home_rounded, Paleta.gris, 0,
        'Tu primera ayuda confirmada te da tu primer reconocimiento.'),
    Nivel('Buen vecino', 'Buen vecino', Icons.eco_rounded, Paleta.verde, 1, 'Ya ayudaste a alguien del barrio.'),
    Nivel('Vecino solidario', 'Solidario', Icons.handshake_rounded, Paleta.primarioClaro, 3,
        'Tus vecinos saben que pueden contar contigo.'),
    Nivel('Corazón del barrio', 'Corazón', Icons.favorite_rounded, Paleta.acentoOscuro, 7,
        'Eres parte de lo que mantiene unido al barrio.'),
    Nivel('Guardián del barrio', 'Guardián', Icons.verified_user_rounded, Paleta.ambar, 15,
        'Un ejemplo para toda la comunidad.'),
  ];

  /// Posición en la escala (0 = Vecino nuevo).
  int get indice => todos.indexOf(this);

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
  const EstadoEmergencia({required this.activa, this.titulo, this.mensaje, this.desde});
  const EstadoEmergencia.inactiva() : this(activa: false);
  final bool activa;
  final String? titulo, mensaje;

  /// Cuándo se activó (identifica esta emergencia para "Estoy bien").
  final DateTime? desde;

  /// Clave estable de esta emergencia (UTC, ISO-8601).
  String? get clave => desde?.toUtc().toIso8601String();

  factory EstadoEmergencia.fromMap(Map<String, dynamic> m) => EstadoEmergencia(
        activa: m['activa'] == true,
        titulo: m['titulo'] as String?,
        mensaje: m['mensaje'] as String?,
        desde: DateTime.tryParse('${m['actualizado_en']}'),
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
        'aceptado' => (Paleta.azulInfo, Paleta.azulSuave),
        'en_proceso' => (Paleta.ambar, Paleta.ambarSuave),
        'completado' => (Paleta.verde, Paleta.verdeSuave),
        'cancelado' => (Paleta.gris, Paleta.grisFondo),
        _ => (Paleta.rosa, Paleta.rosaSuave),
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
    this.autorFotoUrl,
    this.autorRol = 'vecino',
    this.esPrestador = false,
    this.autorOficio,
    required this.sector,
    this.categoriaServicio,
    this.lat,
    this.lng,
    this.apoyos = 0,
    this.apoyadoPorUsuario = false,
    this.dislikes = 0,
    this.dislikePorUsuario = false,
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
  final String? autorFotoUrl;
  final String autorRol;
  final bool esPrestador;
  final String? autorOficio;
  final String sector;
  final String? categoriaServicio;
  final double? lat;
  final double? lng;
  int apoyos;
  bool apoyadoPorUsuario;
  int dislikes;
  bool dislikePorUsuario;
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
            Paleta.azulInfo,
            Paleta.azulSuave,
          ),
        TipoPublicacionForo.recomendacion => (
            'Recomendación',
            Icons.verified_rounded,
            Paleta.ambar,
            Paleta.ambarSuave,
          ),
        TipoPublicacionForo.aviso => (
            'Aviso vecinal',
            Icons.campaign_rounded,
            Paleta.violeta,
            Paleta.violetaSuave,
          ),
        TipoPublicacionForo.dialogo => (
            'Comunidad',
            Icons.forum_rounded,
            Paleta.verde,
            Paleta.verdeSuave,
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
    var conDislike = false;
    int conteoApoyos = (m['apoyos_count'] as num?)?.toInt() ?? 0;
    int conteoDislikes = (m['dislikes_count'] as num?)?.toInt() ?? 0;
    final apoyos = m['foro_apoyos'];
    if (apoyos is List) {
      int likesEnLista = 0;
      int dislikesEnLista = 0;
      for (final a in apoyos) {
        if (a is Map) {
          final tipo = (a['tipo'] ?? 'like') as String;
          if (tipo == 'dislike') {
            dislikesEnLista++;
          } else {
            likesEnLista++;
          }
          if (miUid != null && a['usuario_id'] == miUid) {
            if (tipo == 'dislike') {
              conDislike = true;
            } else {
              apoyado = true;
            }
          }
        }
      }
      if (likesEnLista > conteoApoyos) {
        conteoApoyos = likesEnLista;
      }
      if (dislikesEnLista > conteoDislikes) {
        conteoDislikes = dislikesEnLista;
      }
    }
    if (apoyado && conteoApoyos < 1) {
      conteoApoyos = 1;
    }
    if (conDislike && conteoDislikes < 1) {
      conteoDislikes = 1;
    }

    return TemaForo(
      id: m['id'] as String,
      autorId: m['autor_id'] as String?,
      tipo: t,
      titulo: (m['titulo'] ?? '') as String,
      contenido: (m['contenido'] ?? '') as String,
      autorNombre: (m['autor_nombre'] ?? 'Vecino') as String,
      autorFotoUrl: (m['autor_foto_url'] ?? m['foto_url']) as String?,
      autorRol: (m['autor_rol'] ?? 'vecino') as String,
      esPrestador: m['es_prestador'] == true,
      autorOficio: m['autor_oficio'] as String?,
      sector: (m['sector'] ?? 'Chimbote') as String,
      categoriaServicio: m['categoria_servicio'] as String?,
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      apoyos: conteoApoyos,
      apoyadoPorUsuario: apoyado,
      dislikes: conteoDislikes,
      dislikePorUsuario: conDislike,
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
    this.autorFotoUrl,
    this.autorRol = 'vecino',
    this.esPrestador = false,
    this.autorOficio,
    this.sector,
    this.contactoTelefono,
    this.nombreComercial,
    this.servicioId,
    this.vistosBuenos = 0,
    this.likes = 0,
    this.likePorUsuario = false,
    this.dislikes = 0,
    this.dislikePorUsuario = false,
    this.respuestaAId,
    this.respondiendoA,
    required this.creado,
  });

  final String id;
  final String temaId;
  final String? autorId;
  final String contenido;
  final String autorNombre;
  final String? autorFotoUrl;
  final String autorRol;
  final bool esPrestador;
  final String? autorOficio;
  final String? sector;
  final String? contactoTelefono;
  final String? nombreComercial;
  final String? servicioId;
  final int vistosBuenos;
  int likes;
  bool likePorUsuario;
  int dislikes;
  bool dislikePorUsuario;
  final String? respuestaAId;
  final String? respondiendoA;
  final DateTime creado;

  String get tiempoRelativo {
    final diff = DateTime.now().difference(creado);
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes.clamp(1, 59);
      return 'Hace ${m} min';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return 'Hace ${h} ${h == 1 ? 'hora' : 'horas'}';
    }
    final d = diff.inDays;
    return 'Hace ${d} ${d == 1 ? 'día' : 'días'}';
  }

  String get tiempoCorto {
    final diff = DateTime.now().difference(creado);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays < 7) return '${diff.inDays} d';
    final sem = (diff.inDays / 7).floor();
    return '$sem sem';
  }

  factory RespuestaForo.fromMap(Map<String, dynamic> m, {String? miUid}) {
    var dioLike = false;
    var dioDislike = false;
    final lk = m['foro_respuestas_likes'];
    int totalLikes = (m['likes_count'] as num?)?.toInt() ??
        (m['vistos_buenos'] as num?)?.toInt() ??
        0;
    int totalDislikes = (m['dislikes_count'] as num?)?.toInt() ?? 0;
    if (lk is List) {
      int likesEnLista = 0;
      int dislikesEnLista = 0;
      for (final l in lk) {
        if (l is Map) {
          final tipo = (l['tipo'] ?? 'like') as String;
          if (tipo == 'dislike') {
            dislikesEnLista++;
          } else {
            likesEnLista++;
          }
          if (miUid != null && l['usuario_id'] == miUid) {
            if (tipo == 'dislike') {
              dioDislike = true;
            } else {
              dioLike = true;
            }
          }
        }
      }
      if (likesEnLista > totalLikes) {
        totalLikes = likesEnLista;
      }
      if (dislikesEnLista > totalDislikes) {
        totalDislikes = dislikesEnLista;
      }
    }
    if (dioLike && totalLikes < 1) {
      totalLikes = 1;
    }
    if (dioDislike && totalDislikes < 1) {
      totalDislikes = 1;
    }

    return RespuestaForo(
      id: m['id'] as String,
      temaId: m['tema_id'] as String,
      autorId: m['autor_id'] as String?,
      contenido: (m['contenido'] ?? '') as String,
      autorNombre: (m['autor_nombre'] ?? 'Vecino') as String,
      autorFotoUrl: (m['autor_foto_url'] ?? m['foto_url']) as String?,
      autorRol: (m['autor_rol'] ?? 'vecino') as String,
      esPrestador: m['es_prestador'] == true,
      autorOficio: m['autor_oficio'] as String?,
      sector: m['sector'] as String?,
      contactoTelefono: m['contacto_telefono'] as String?,
      nombreComercial: m['nombre_comercial'] as String?,
      servicioId: m['servicio_id'] as String?,
      vistosBuenos: (m['vistos_buenos'] as num?)?.toInt() ?? 0,
      likes: totalLikes,
      likePorUsuario: dioLike,
      dislikes: totalDislikes,
      dislikePorUsuario: dioDislike,
      respuestaAId: m['respuesta_a_id'] as String?,
      respondiendoA: m['respondiendo_a'] as String?,
      creado: DateTime.tryParse(m['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

// ================================================================ brigadistas

/// Especialidades de un brigadista (las nombra la junta vecinal).
const especialidadesBrigadista = <(String, String, IconData)>[
  ('primeros_auxilios', 'Primeros auxilios', Icons.medical_services_outlined),
  ('rescate', 'Rescate', Icons.support_outlined),
  ('evacuacion', 'Evacuación', Icons.directions_run_rounded),
  ('logistica', 'Víveres y logística', Icons.inventory_2_outlined),
  ('comunicacion', 'Comunicación', Icons.campaign_outlined),
  ('general', 'Apoyo general', Icons.volunteer_activism_outlined),
];

(String, String, IconData) especialidadBrigadista(String id) =>
    especialidadesBrigadista.firstWhere((e) => e.$1 == id, orElse: () => especialidadesBrigadista.last);

/// Un brigadista del sector: invitado (falta que acepte) o activo.
class Brigadista {
  Brigadista({required this.vecinoId, required this.sector, required this.especialidad, required this.estado, this.nombre, this.creado});
  final String vecinoId, sector, especialidad, estado;
  final String? nombre;
  final DateTime? creado;

  bool get activo => estado == 'activo';
  bool get invitado => estado == 'invitado';
  String get especialidadNombre => especialidadBrigadista(especialidad).$2;

  factory Brigadista.fromMap(Map<String, dynamic> m) => Brigadista(
        vecinoId: m['vecino_id'] as String,
        sector: (m['sector'] ?? '') as String,
        especialidad: (m['especialidad'] ?? 'general') as String,
        estado: (m['estado'] ?? 'invitado') as String,
        nombre: (m['perfiles'] as Map?)?['nombre'] as String?,
        creado: DateTime.tryParse('${m['created_at']}')?.toLocal(),
      );

  Map<String, dynamic> toJson() =>
      {'vecino_id': vecinoId, 'sector': sector, 'especialidad': especialidad, 'estado': estado, 'perfiles': {'nombre': nombre}};
}

/// Vecino del sector, para el panel de la junta (sin datos privados).
class MiembroSector {
  MiembroSector({required this.id, required this.nombre, required this.verificado, required this.ayudas});
  final String id, nombre;
  final bool verificado;
  final int ayudas;

  factory MiembroSector.fromMap(Map<String, dynamic> m) => MiembroSector(
        id: m['id'] as String,
        nombre: (m['nombre'] ?? 'Vecino') as String,
        verificado: m['verificado_gps'] == true,
        ayudas: (m['ayudas_confirmadas'] as num?)?.toInt() ?? 0,
      );
}

/// Canal de comunicación del sector (grupo de WhatsApp, teléfono, reunión...).
class CanalSector {
  CanalSector({this.id, required this.sector, required this.tipo, required this.etiqueta, required this.valor, this.publico = true});
  final String? id;
  final String sector, tipo, etiqueta, valor;
  final bool publico;

  IconData get icono => switch (tipo) {
        'whatsapp' => Icons.chat_rounded,
        'telegram' => Icons.send_rounded,
        'telefono' => Icons.call_rounded,
        'reunion' => Icons.groups_rounded,
        _ => Icons.link_rounded,
      };

  String get tipoNombre => switch (tipo) {
        'whatsapp' => 'WhatsApp',
        'telegram' => 'Telegram',
        'telefono' => 'Teléfono',
        'reunion' => 'Reuniones',
        _ => 'Otro',
      };

  /// Enlace que se abre al tocar (null si es solo texto, como una reunión).
  Uri? get enlace {
    final v = valor.trim();
    if (tipo == 'telefono') return Uri.parse('tel:${v.replaceAll(RegExp(r'[^0-9+]'), '')}');
    if (v.startsWith('http://') || v.startsWith('https://')) return Uri.tryParse(v);
    return null;
  }

  factory CanalSector.fromMap(Map<String, dynamic> m) => CanalSector(
        id: m['id'] as String?,
        sector: (m['sector'] ?? '') as String,
        tipo: (m['tipo'] ?? 'otro') as String,
        etiqueta: (m['etiqueta'] ?? '') as String,
        valor: (m['valor'] ?? '') as String,
        publico: m['publico'] != false,
      );

  Map<String, dynamic> toInsert() =>
      {if (id != null) 'id': id, 'sector': sector, 'tipo': tipo, 'etiqueta': etiqueta, 'valor': valor, 'publico': publico};
}
