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
    required this.onToggleApoyo,
  });

  final TemaForo tema;
  final VoidCallback onToggleApoyo;

  @override
  State<DetalleTemaForoScreen> createState() => _DetalleTemaForoScreenState();
}

class _DetalleTemaForoScreenState extends State<DetalleTemaForoScreen> {
  final TextEditingController _respuestaCtrl = TextEditingController();
  FocusNode? _focusNode;
  FocusNode get _nodoFoco => _focusNode ??= FocusNode();
  String? _respondiendoA;
  bool _enviando = false;

  @override
  void dispose() {
    _respuestaCtrl.dispose();
    _focusNode?.dispose();
    super.dispose();
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
      await st.repo.crearRespuestaForo({
        'tema_id': widget.tema.id,
        'autor_id': st.uid,
        'contenido': texto,
        'sector': st.sector,
        if (aQuien != null && aQuien.isNotEmpty) 'respondiendo_a': aQuien,
      });

      _respuestaCtrl.clear();
      setState(() => _respondiendoA = null);
      st.refrescar();

      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tu respuesta ha sido enviada.'),
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
          st.refrescar();
          setState(() {});
        },
      ),
    );
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
          IconButton(
            tooltip: 'Apoyar tema',
            icon: Icon(
              t.apoyadoPorUsuario
                  ? Icons.thumb_up_alt_rounded
                  : Icons.thumb_up_alt_outlined,
              color: t.apoyadoPorUsuario
                  ? const Color(0xFF2E7D32)
                  : Paleta.tinta,
            ),
            onPressed: () {
              widget.onToggleApoyo();
              setState(() {});
            },
          ),
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
                    st.refrescar();
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
                        color: const Color(0xFF16A34A),
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
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
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
                                                const SizedBox(width: 4),
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
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (t.estado == 'resuelto') ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDCFCE7),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFF86EFAC)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_circle, size: 10, color: Color(0xFF16A34A)),
                                                SizedBox(width: 2.5),
                                                Text(
                                                  'Resuelto',
                                                  style: TextStyle(
                                                    color: Color(0xFF166534),
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                        ],
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: fondoTipo,
                                            borderRadius: BorderRadius.circular(8),
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
                                    color: Color(0xFF334155),
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
                                Row(
                                  children: [
                                    Icon(
                                      Icons.thumb_up_alt_outlined,
                                      size: 15,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${t.apoyos} vecinos interesados en esta consulta',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Paleta.gris,
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
                  'Respuestas y recomendaciones',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Paleta.tinta,
                  ),
                ),

                const SizedBox(height: 10),

                // Lista de respuestas
                Cargador<List<RespuestaForo>>(
                  claves: [st.version],
                  cargar: (st) async {
                    final filas = await st.repo.respuestasForo(t.id);
                    return filas.map(RespuestaForo.fromMap).toList();
                  },
                  builder: (context, respuestas) {
                    if (respuestas.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFFBEB), Colors.white],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x061E293B),
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.handyman_rounded,
                                  size: 26,
                                  color: Color(0xFFD97706),
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
                                    backgroundColor: const Color(0xFFD97706),
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
                    return Column(
                      children: respuestas
                          .map((r) => TarjetaRespuesta(
                                r: r,
                                onResponder: () {
                                  setState(() => _respondiendoA = r.autorNombre);
                                  _nodoFoco.requestFocus();
                                },
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
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancelar'),
                                        ),
                                        FilledButton(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Paleta.rojo,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Eliminar'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmar == true) {
                                    await st.repo.eliminarRespuestaForo(r.id);
                                    st.refrescar();
                                  }
                                },
                              ))
                          .toList(),
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
                    onTap: () => setState(() => _respondiendoA = null),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 18, color: Paleta.gris),
                    ),
                  ),
                ],
              ),
            ),

          // Caja fija inferior para responder
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 16, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Paleta.linea)),
            ),
            child: Row(
              children: [
                if (t.tipo == TipoPublicacionForo.servicio) ...[
                  IconButton(
                    tooltip: 'Recomendar prestador con teléfono',
                    style: IconButton.styleFrom(
                      backgroundColor: Paleta.acentoSuave,
                      foregroundColor: Paleta.acentoOscuro,
                    ),
                    onPressed: _abrirModalRecomendar,
                    icon: const Icon(Icons.handyman_outlined, size: 20),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: TextField(
                    controller: _respuestaCtrl,
                    focusNode: _nodoFoco,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _respondiendoA != null
                          ? 'Escribe tu respuesta a @$_respondiendoA...'
                          : (t.tipo == TipoPublicacionForo.servicio
                              ? 'Escribe tu respuesta o recomendación...'
                              : 'Escribe tu respuesta...'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Paleta.linea),
                      ),
                      filled: true,
                      fillColor: Paleta.crema,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: Paleta.primario),
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
