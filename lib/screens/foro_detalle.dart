import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/diseno.dart';
import '../ui/tema.dart';
import '../ui/widgets.dart';
import 'auth_screen.dart';
import 'foro_modales.dart';
import 'foro_widgets.dart';

/// Pantalla de detalle de la conversación en el foro.
class DetalleTemaForoScreen extends StatefulWidget {
  const DetalleTemaForoScreen({
    super.key,
    required this.tema,
    this.onToggleApoyo,
    this.onToggleDislike,
  });

  final TemaForo tema;
  final VoidCallback? onToggleApoyo;
  final VoidCallback? onToggleDislike;

  @override
  State<DetalleTemaForoScreen> createState() => _DetalleTemaForoScreenState();
}

class _DetalleTemaForoScreenState extends State<DetalleTemaForoScreen> {
  final TextEditingController _respuestaCtrl = TextEditingController();
  FocusNode? _focusNode;
  FocusNode get _nodoFoco => _focusNode ??= FocusNode();
  String? _respondiendoA;
  String? _respuestaAPadreId;
  bool _enviando = false;
  Timer? _timerRefresco;

  final Set<String> _respuestasExpandidas = {};
  final Set<String> _procesandoLikes = {};

  // Memoria optimista de reacciones locales para respuesta inmediata en 0ms
  final Map<String, ({bool like, bool dislike, int likes, int dislikes})> _reaccionesLocales = {};
  int _versionRespuestas = 0;

  @override
  void initState() {
    super.initState();
    // Refresco periódico no intrusivo en vivo cada 15 segundos sin bloquear la UI
    _timerRefresco = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timerRefresco?.cancel();
    _respuestaCtrl.dispose();
    _focusNode?.dispose();
    super.dispose();
  }

  Future<void> _toggleTemaLike() async {
    final st = context.read<AppState>();
    if (!st.logueado) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthScreen(
            mensaje: 'Para apoyar una consulta necesitas ingresar con tu cuenta de vecino.',
          ),
        ),
      );
      return;
    }

    final t = widget.tema;
    final teniaLike = t.apoyadoPorUsuario;
    final teniaDislike = t.dislikePorUsuario;
    final nuevoLike = !teniaLike;

    setState(() {
      t.apoyadoPorUsuario = nuevoLike;
      if (nuevoLike) {
        t.apoyos = (t.apoyos + 1).clamp(1, 999999);
        if (teniaDislike) {
          t.dislikePorUsuario = false;
          t.dislikes = (t.dislikes - 1).clamp(0, 999999);
        }
      } else {
        t.apoyos = (t.apoyos - 1).clamp(0, 999999);
      }
    });

    try {
      await st.repo.toggleReaccionTemaForo(t.id, tipo: 'like', activar: nuevoLike);
    } catch (_) {
      if (mounted) {
        setState(() {
          t.apoyadoPorUsuario = teniaLike;
          t.dislikePorUsuario = teniaDislike;
        });
      }
    }
  }

  Future<void> _toggleTemaDislike() async {
    final st = context.read<AppState>();
    if (!st.logueado) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthScreen(
            mensaje: 'Para reaccionar en una consulta necesitas ingresar con tu cuenta de vecino.',
          ),
        ),
      );
      return;
    }

    final t = widget.tema;
    final teniaLike = t.apoyadoPorUsuario;
    final teniaDislike = t.dislikePorUsuario;
    final nuevoDislike = !teniaDislike;

    setState(() {
      t.dislikePorUsuario = nuevoDislike;
      if (nuevoDislike) {
        t.dislikes = (t.dislikes + 1).clamp(1, 999999);
        if (teniaLike) {
          t.apoyadoPorUsuario = false;
          t.apoyos = (t.apoyos - 1).clamp(0, 999999);
        }
      } else {
        t.dislikes = (t.dislikes - 1).clamp(0, 999999);
      }
    });

    try {
      await st.repo.toggleReaccionTemaForo(t.id, tipo: 'dislike', activar: nuevoDislike);
    } catch (_) {
      if (mounted) {
        setState(() {
          t.dislikePorUsuario = teniaDislike;
          t.apoyadoPorUsuario = teniaLike;
        });
      }
    }
  }

  Future<void> _enviarRespuesta() async {
    final texto = _respuestaCtrl.text.trim();
    if (texto.isEmpty || _enviando) return;

    final st = context.read<AppState>();
    if (!st.logueado) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthScreen(
            mensaje: 'Para responder en el foro debes ingresar con tu cuenta de vecino.',
          ),
        ),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      final aQuien = _respondiendoA;
      final padreId = _respuestaAPadreId;
      await st.repo.crearRespuestaForo({
        'tema_id': widget.tema.id,
        'autor_id': st.uid,
        'contenido': texto,
        'sector': st.sector,
        if (aQuien != null && aQuien.isNotEmpty) 'respondiendo_a': aQuien,
        if (padreId != null && padreId.isNotEmpty) 'respuesta_a_id': padreId,
      });

      _respuestaCtrl.clear();
      setState(() {
        _respondiendoA = null;
        _respuestaAPadreId = null;
        _versionRespuestas++;
        widget.tema.respuestasCount++;
      });

      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tu comentario ha sido publicado.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _abrirModalRecomendar() {
    final st = context.read<AppState>();
    if (!st.logueado) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthScreen(
            mensaje: 'Para recomendar a un prestador debes ingresar con tu cuenta de vecino.',
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalRecomendarPrestador(
        tema: widget.tema,
        onRecomendado: () {
          setState(() {
            _versionRespuestas++;
            widget.tema.respuestasCount++;
          });
        },
      ),
    );
  }

  void _toggleLikeComentario(RespuestaForo r, {required bool esLike}) {
    if (_procesandoLikes.contains(r.id)) return;
    final st = context.read<AppState>();
    if (!st.logueado) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthScreen(
            mensaje: 'Para reaccionar a un comentario debes ingresar con tu cuenta de vecino.',
          ),
        ),
      );
      return;
    }

    _procesandoLikes.add(r.id);
    final previa = _reaccionesLocales[r.id];
    final teniaLike = previa?.like ?? r.likePorUsuario;
    final teniaDislike = previa?.dislike ?? r.dislikePorUsuario;
    var nuevoLike = teniaLike;
    var nuevoDislike = teniaDislike;
    var nuevosLikes = previa?.likes ?? r.likes;
    var nuevosDislikes = previa?.dislikes ?? r.dislikes;

    if (esLike) {
      nuevoLike = !teniaLike;
      if (nuevoLike) {
        nuevosLikes = (nuevosLikes + 1).clamp(1, 999999);
        if (teniaDislike) {
          nuevoDislike = false;
          nuevosDislikes = (nuevosDislikes - 1).clamp(0, 999999);
        }
      } else {
        nuevosLikes = (nuevosLikes - 1).clamp(0, 999999);
      }
    } else {
      nuevoDislike = !teniaDislike;
      if (nuevoDislike) {
        nuevosDislikes = (nuevosDislikes + 1).clamp(1, 999999);
        if (teniaLike) {
          nuevoLike = false;
          nuevosLikes = (nuevosLikes - 1).clamp(0, 999999);
        }
      } else {
        nuevosDislikes = (nuevosDislikes - 1).clamp(0, 999999);
      }
    }

    // Respuesta instantánea en 0ms en pantalla
    setState(() {
      _reaccionesLocales[r.id] = (
        like: nuevoLike,
        dislike: nuevoDislike,
        likes: nuevosLikes,
        dislikes: nuevosDislikes,
      );
      r.likePorUsuario = nuevoLike;
      r.dislikePorUsuario = nuevoDislike;
      r.likes = nuevosLikes;
      r.dislikes = nuevosDislikes;
    });

    // Enviar a la base de datos de fondo
    final nuevoEstado = esLike ? nuevoLike : nuevoDislike;
    st.repo.toggleReaccionRespuestaForo(
      r.id,
      tipo: esLike ? 'like' : 'dislike',
      activar: nuevoEstado,
    ).then((_) {
      _procesandoLikes.remove(r.id);
    }).catchError((_) {
      _procesandoLikes.remove(r.id);
      if (mounted) {
        setState(() {
          if (previa != null) {
            _reaccionesLocales[r.id] = previa;
            r.likePorUsuario = previa.like;
            r.dislikePorUsuario = previa.dislike;
            r.likes = previa.likes;
            r.dislikes = previa.dislikes;
          } else {
            _reaccionesLocales.remove(r.id);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tema;
    final (nombreTipo, iconoTipo, colorTipo, fondoTipo) = t.datosTipo;
    final st = context.watch<AppState>();
    final esMiTema = st.uid != null && st.uid == t.autorId;

    return Scaffold(
      backgroundColor: Paleta.crema,
      appBar: AppBar(
        title: const Text(
          'Conversación vecinal',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          if (esMiTema)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Paleta.tinta),
              tooltip: 'Opciones de mi publicación',
              onSelected: (accion) async {
                if (accion == 'eliminar') {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      title: const Text('¿Eliminar publicación?'),
                      content: const Text(
                        'Esta acción borrará la consulta del foro permanentemente.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Paleta.rojo,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Eliminar'),
                        ),
                      ],
                    ),
                  );
                  if (confirmar == true && context.mounted) {
                    await st.repo.eliminarTemaForo(t.id);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Publicación eliminada.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                } else if (accion == 'resolver') {
                  final nuevoEstado =
                      t.estado == 'resuelto' ? 'abierto' : 'resuelto';
                  await st.repo.cambiarEstadoTemaForo(t.id, nuevoEstado);
                  setState(() => t.estado = nuevoEstado);
                  st.refrescar();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'resolver',
                  child: Row(
                    children: [
                      Icon(
                        t.estado == 'resuelto'
                            ? Icons.replay
                            : Icons.check_circle_outline,
                        size: 18,
                        color: Paleta.verde,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.estado == 'resuelto'
                            ? 'Reabrir consulta'
                            : 'Marcar como resuelto',
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'eliminar',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Paleta.rojo),
                      SizedBox(width: 8),
                      Text(
                        'Eliminar publicación',
                        style: TextStyle(color: Paleta.rojo),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Publicación principal con borde seguro y franja lateral
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Paleta.linea),
                    boxShadow: [
                      BoxShadow(
                        color: colorTipo.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(width: 5, color: colorTipo),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: colorAvatar(t.autorNombre).$1,
                                      child: Text(
                                        iniciales(t.autorNombre),
                                        style: TextStyle(
                                          color: colorAvatar(t.autorNombre).$2,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  t.autorNombre,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                    color: Paleta.tinta,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (badgeRolAutor(t.autorRol) != null) ...[
                                                const SizedBox(width: 5),
                                                badgeRolAutor(t.autorRol)!,
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${t.sector} · ${t.tiempoRelativo}',
                                            style: const TextStyle(
                                              color: Paleta.gris,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (t.estado == 'resuelto') ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: const Color(0xFF86EFAC),
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.check_circle,
                                                  size: 12,
                                                  color: Color(0xFF16A34A),
                                                ),
                                                SizedBox(width: 3),
                                                Text(
                                                  'Resuelto',
                                                  style: TextStyle(
                                                    color: Color(0xFF166534),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                        ],
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: fondoTipo,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: colorTipo.withValues(alpha: 0.25),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(iconoTipo, size: 12, color: colorTipo),
                                              const SizedBox(width: 4),
                                              Text(
                                                nombreTipo,
                                                style: TextStyle(
                                                  color: colorTipo,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  t.titulo,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    height: 1.25,
                                    color: Paleta.tinta,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  t.contenido,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Paleta.primarioClaro,
                                    height: 1.45,
                                  ),
                                ),
                                if (t.categoriaServicio != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Paleta.acentoSuave,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Paleta.acentoOscuro.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.handyman_outlined,
                                          size: 16,
                                          color: Paleta.acentoOscuro,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Oficio requerido: ${buscarCategoria(t.categoriaServicio!).nombre}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: Paleta.acentoOscuro,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                const Divider(height: 1, color: Paleta.linea),
                                const SizedBox(height: 10),

                                // Botones táctiles de Me gusta y No me gusta dentro de la tarjeta
                                Row(
                                  children: [
                                    // Botón Me gusta
                                    Material(
                                      color: t.apoyadoPorUsuario
                                          ? const Color(0xFFEFF6FF)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(20),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: _toggleTemaLike,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: t.apoyadoPorUsuario
                                                  ? const Color(0xFF93C5FD)
                                                  : Paleta.linea,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                t.apoyadoPorUsuario
                                                    ? Icons.thumb_up_alt_rounded
                                                    : Icons.thumb_up_alt_outlined,
                                                size: 16,
                                                color: t.apoyadoPorUsuario
                                                    ? const Color(0xFF2563EB)
                                                    : Paleta.gris,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${t.apoyos} me gusta',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: t.apoyadoPorUsuario
                                                      ? const Color(0xFF2563EB)
                                                      : Paleta.tinta,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Botón No me gusta
                                    Material(
                                      color: t.dislikePorUsuario
                                          ? const Color(0xFFFEF2F2)
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(20),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: _toggleTemaDislike,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: t.dislikePorUsuario
                                                  ? const Color(0xFFFCA5A5)
                                                  : Paleta.linea,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                t.dislikePorUsuario
                                                    ? Icons.thumb_down_alt_rounded
                                                    : Icons.thumb_down_alt_outlined,
                                                size: 16,
                                                color: t.dislikePorUsuario
                                                    ? const Color(0xFFDC2626)
                                                    : Paleta.gris,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${t.dislikes} no me gusta',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: t.dislikePorUsuario
                                                      ? const Color(0xFFDC2626)
                                                      : Paleta.tinta,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Subtítulo de respuestas
                const Text(
                  'Respuestas y comentarios',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: Paleta.tinta,
                  ),
                ),
                const SizedBox(height: 10),

                // Lista de respuestas
                Cargador<List<Map<String, dynamic>>>(
                  claves: [_versionRespuestas],
                  cargar: (st) => st.repo.respuestasForo(t.id),
                  builder: (context, filas) {
                    final respuestas = filas.map((m) {
                      final item = RespuestaForo.fromMap(m, miUid: st.uid);
                      final override = _reaccionesLocales[item.id];
                      if (override != null) {
                        item.likePorUsuario = override.like;
                        item.dislikePorUsuario = override.dislike;
                        item.likes = override.likes;
                        item.dislikes = override.dislikes;
                      }
                      return item;
                    }).toList();

                    if (respuestas.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Paleta.linea),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Paleta.ambarSuave,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.handyman_rounded,
                                  size: 26,
                                  color: Paleta.ambar,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '¿Conoces a un especialista para este caso?',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Paleta.tinta,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Recomienda a un prestador de confianza o deja su contacto para ayudar al vecino.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Paleta.gris,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                              if (t.tipo == TipoPublicacionForo.servicio) ...[
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Paleta.ambar,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 11,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _abrirModalRecomendar,
                                  icon: const Icon(
                                    Icons.recommend_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Recomendar a un prestador',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }

                    // Organización jerárquica O(N) estilo Instagram
                    final List<RespuestaForo> padres = [];
                    final Map<String, List<RespuestaForo>> hijosPorPadre = {};

                    for (final r in respuestas) {
                      if (r.respuestaAId == null || r.respuestaAId!.isEmpty) {
                        padres.add(r);
                      } else {
                        hijosPorPadre.putIfAbsent(r.respuestaAId!, () => []).add(r);
                      }
                    }

                    return Column(
                      children: padres.map((padre) {
                        final hijos = hijosPorPadre[padre.id] ?? const [];
                        final estaExpandido = _respuestasExpandidas.contains(padre.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Paleta.linea),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Comentario padre
                              TarjetaRespuesta(
                                r: padre,
                                onResponder: () {
                                  setState(() {
                                    _respondiendoA = padre.autorNombre;
                                    _respuestaAPadreId = padre.id;
                                  });
                                  _nodoFoco.requestFocus();
                                },
                                onLike: () => _toggleLikeComentario(padre, esLike: true),
                                onDislike: () => _toggleLikeComentario(padre, esLike: false),
                                onEliminar: () async {
                                  final confirmar = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: const Text('¿Eliminar respuesta?'),
                                      content: const Text(
                                        'Se borrará tu comentario permanentemente.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Paleta.rojo,
                                          ),
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Eliminar'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmar == true) {
                                    await st.repo.eliminarRespuestaForo(padre.id);
                                    if (mounted) {
                                      setState(() {
                                        _versionRespuestas++;
                                        widget.tema.respuestasCount = (widget.tema.respuestasCount - 1).clamp(0, 999999);
                                      });
                                    }
                                  }
                                },
                              ),

                              // Botón desplegable estilo Instagram para ver respuestas
                              if (hijos.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (estaExpandido) {
                                        _respuestasExpandidas.remove(padre.id);
                                      } else {
                                        _respuestasExpandidas.add(padre.id);
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 1,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          estaExpandido
                                              ? 'Ocultar respuestas'
                                              : 'Ver respuestas (${hijos.length})',
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              // Respuestas hijas indentadas con línea vertical
                              if (estaExpandido && hijos.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(left: 12, top: 8),
                                  padding: const EdgeInsets.only(left: 12),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      left: BorderSide(color: Color(0xFFE2E8F0), width: 2),
                                    ),
                                  ),
                                  child: Column(
                                    children: hijos
                                        .map(
                                          (hijo) => TarjetaRespuesta(
                                            r: hijo,
                                            esHija: true,
                                            onResponder: () {
                                              setState(() {
                                                _respondiendoA = hijo.autorNombre;
                                                _respuestaAPadreId = padre.id;
                                              });
                                              _nodoFoco.requestFocus();
                                            },
                                            onLike: () => _toggleLikeComentario(hijo, esLike: true),
                                            onDislike: () => _toggleLikeComentario(hijo, esLike: false),
                                            onEliminar: () async {
                                              final confirmar = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  title: const Text('¿Eliminar respuesta?'),
                                                  content: const Text(
                                                    'Se borrará tu comentario permanentemente.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(ctx, false),
                                                      child: const Text('Cancelar'),
                                                    ),
                                                    FilledButton(
                                                      style: FilledButton.styleFrom(
                                                        backgroundColor: Paleta.rojo,
                                                      ),
                                                      onPressed: () => Navigator.pop(ctx, true),
                                                      child: const Text('Eliminar'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirmar == true) {
                                                await st.repo.eliminarRespuestaForo(hijo.id);
                                                if (mounted) {
                                                  setState(() {
                                                    _versionRespuestas++;
                                                    widget.tema.respuestasCount = (widget.tema.respuestasCount - 1).clamp(0, 999999);
                                                  });
                                                }
                                              }
                                            },
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),

          // Banner si se está respondiendo a un comentario específico
          if (_respondiendoA != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                border: Border(top: BorderSide(color: Colors.blue.shade100)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 16, color: Color(0xFF1D4ED8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Respondiendo a @$_respondiendoA',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D4ED8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() {
                      _respondiendoA = null;
                      _respuestaAPadreId = null;
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 18, color: Paleta.gris),
                    ),
                  ),
                ],
              ),
            ),

          // Barra explicativa clara si la publicación busca un servicio/oficio
          if (t.tipo == TipoPublicacionForo.servicio)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFFFFBEB),
                border: Border(
                  top: BorderSide(color: Color(0xFFFDE68A)),
                  bottom: BorderSide(color: Color(0xFFFEF3C7)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.handyman_rounded,
                      size: 15,
                      color: Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '¿Conoces a un especialista? Comparte su teléfono para que el vecino pueda llamarlo.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _abrirModalRecomendar,
                    icon: const Icon(Icons.add_call, size: 13),
                    label: const Text(
                      'Recomendar',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Caja fija inferior para responder
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Paleta.linea)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _respuestaCtrl,
                    focusNode: _nodoFoco,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: _respondiendoA != null
                          ? 'Respondiendo a @$_respondiendoA...'
                          : 'Escribe un comentario público...',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Paleta.linea),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Paleta.linea),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: Paleta.primario,
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Paleta.primario,
                    padding: const EdgeInsets.all(12),
                  ),
                  onPressed: _enviando ? null : _enviarRespuesta,
                  icon: _enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
