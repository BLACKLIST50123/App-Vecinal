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
