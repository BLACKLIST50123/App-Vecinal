import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/diseno.dart';
import '../ui/tema.dart';
import '../ui/widgets.dart';
import '../ui/foto_perfil.dart';

/// Formatea celular peruano (9 dígitos en grupos de 3: 981 150 402)
String _formatearCelularPeru(String tel) {
  var d = tel.replaceAll(RegExp(r'\D'), '');
  if (d.length == 11 && d.startsWith('51')) {
    d = d.substring(2);
  }
  if (d.length == 9) {
    return '' + d.substring(0, 3) + ' ' + d.substring(3, 6) + ' ' + d.substring(6);
  }
  return tel;
}

/// Paleta armónica para avatares vecinales con vida y color.
(Color, Color) colorAvatar(String nombre) {
  const paletas = [
    (Paleta.rojoSuave, Paleta.rojo), // Coral / Rojo
    (Paleta.ambarSuave, Paleta.ambar), // Naranja cálido
    (Paleta.ambarSuave, Paleta.ambar), // Ámbar
    (Paleta.verdeSuave, Paleta.verde), // Esmeralda
    (Paleta.verdeSuave, Paleta.verde), // Verde
    (Paleta.verdeSuave, Paleta.verde), // Turquesa
    (Paleta.azulSuave, Paleta.azulInfo), // Celeste
    (Paleta.azulSuave, Paleta.azulInfo), // Índigo
    (Paleta.violetaSuave, Paleta.violeta), // Púrpura
  ];
  final hash = nombre.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
  return paletas[hash % paletas.length];
}

/// Distintivo de rol comunitario (Brigadista o Líder).
Widget? badgeRolAutor(String? rol) {
  if (rol == null || rol == 'vecino' || rol == 'moderador' || rol.isEmpty) {
    return null;
  }
  final (texto, icono, color) = switch (rol.toLowerCase()) {
    'brigadista' => (
        'Brigadista',
        Icons.health_and_safety_outlined,
        Paleta.rojoTexto,
      ),
    'lider' || 'lider_comunitario' => (
        'Líder Comunitario',
        Icons.shield_outlined,
        Paleta.azulInfo,
      ),
    _ => (
        rol[0].toUpperCase() + rol.substring(1),
        Icons.verified_user_outlined,
        Paleta.azulInfo,
      ),
  };
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          texto,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// Tarjeta estructurada de una publicación en el feed del foro vecinal.
/// Diseño con franja lateral segura, jerarquía visual clara y sin truncamientos incómodos.
class TarjetaForo extends StatelessWidget {
  const TarjetaForo({
    super.key,
    required this.tema,
    required this.onTap,
    required this.onApoyar,
    required this.onDislike,
  });

  final TemaForo tema;
  final VoidCallback onTap;
  final VoidCallback onApoyar;
  final VoidCallback onDislike;

  @override
  Widget build(BuildContext context) {
    final (nombreTipo, iconoTipo, colorTipo, fondoTipo) = tema.datosTipo;
    final (bgAvatar, fgAvatar) = colorAvatar(tema.autorNombre);
    final st = context.watch<AppState>();
    final esMiTema = st.uid != null && st.uid == tema.autorId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
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
            // Franja lateral con el color distintivo de la categoría
            Container(width: 5, color: colorTipo),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cabecera: Autor + Categoría alineados limpiamente
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            AvatarVecino(
                              nombre: tema.autorNombre,
                              fotoUrl: tema.autorFotoUrl,
                              tamano: 38,
                              colorFondo: bgAvatar,
                              colorTexto: fgAvatar,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          tema.autorNombre,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Paleta.tinta,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (badgeRolAutor(tema.autorRol) != null) ...[
                                        const SizedBox(width: 4),
                                        badgeRolAutor(tema.autorRol)!,
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_outlined,
                                        size: 13,
                                        color: Paleta.gris,
                                      ),
                                      const SizedBox(width: 2),
                                      Expanded(
                                        child: Text(
                                          '${tema.sector} · ${tema.tiempoRelativo}',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Paleta.gris,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Badges a la derecha
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (tema.estado == 'resuelto') ...[
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
                                if (esMiTema) ...[
                                  const SizedBox(width: 2),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 18, color: Paleta.gris),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
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
                                        if (confirmar == true) {
                                          await st.repo.eliminarTemaForo(tema.id);
                                          st.refrescar();
                                        }
                                      } else if (accion == 'resolver') {
                                        final nuevoEstado =
                                            tema.estado == 'resuelto' ? 'abierto' : 'resuelto';
                                        await st.repo.cambiarEstadoTemaForo(
                                          tema.id,
                                          nuevoEstado,
                                        );
                                        st.refrescar();
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'resolver',
                                        child: Row(
                                          children: [
                                            Icon(
                                              tema.estado == 'resuelto'
                                                  ? Icons.replay
                                                  : Icons.check_circle_outline,
                                              size: 18,
                                              color: const Color(0xFF16A34A),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              tema.estado == 'resuelto'
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
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Título
                        Text(
                          tema.titulo,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                            letterSpacing: -0.2,
                            color: Paleta.tinta,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Contenido
                        Text(
                          tema.contenido,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Paleta.primarioClaro,
                            height: 1.45,
                          ),
                        ),

                        // Oficio si aplica
                        if (tema.categoriaServicio != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Paleta.acentoSuave,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Paleta.acentoOscuro.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.handyman_outlined,
                                  size: 14,
                                  color: Paleta.acentoOscuro,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Oficio requerido: ${buscarCategoria(tema.categoriaServicio!).nombre}',
                                  style: const TextStyle(
                                    color: Paleta.acentoOscuro,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),
                        const Divider(height: 1, color: Paleta.linea),
                        const SizedBox(height: 10),

                        // Pie de tarjeta
                        Row(
                          children: [
                            // Botón Like
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: onApoyar,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      tema.apoyadoPorUsuario
                                          ? Icons.thumb_up_alt_rounded
                                          : Icons.thumb_up_alt_outlined,
                                      size: 16,
                                      color: tema.apoyadoPorUsuario ? const Color(0xFF2563EB) : Paleta.gris,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${tema.apoyos}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: tema.apoyadoPorUsuario ? const Color(0xFF2563EB) : Paleta.gris,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Botón Dislike
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: onDislike,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      tema.dislikePorUsuario
                                          ? Icons.thumb_down_alt_rounded
                                          : Icons.thumb_down_alt_outlined,
                                      size: 16,
                                      color: tema.dislikePorUsuario ? const Color(0xFFDC2626) : Paleta.gris,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${tema.dislikes}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: tema.dislikePorUsuario ? const Color(0xFFDC2626) : Paleta.gris,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Comentarios (conteo limpio sin colisiones)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 16,
                                  color: Paleta.gris,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${tema.respuestasCount}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Paleta.gris,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Acción
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tema.tipo == TipoPublicacionForo.servicio
                                      ? 'Recomendar'
                                      : 'Conversar',
                                  style: const TextStyle(
                                    color: Paleta.primario,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: Paleta.primario,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de respuesta profesional y estructurada con soporte para hilos jerárquicos y likes.
class TarjetaRespuesta extends StatelessWidget {
  const TarjetaRespuesta({
    super.key,
    required this.r,
    required this.onEliminar,
    required this.onResponder,
    required this.onLike,
    required this.onDislike,
    this.esHija = false,
  });

  final RespuestaForo r;
  final VoidCallback onEliminar;
  final VoidCallback onResponder;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final bool esHija;

  @override
  Widget build(BuildContext context) {
    final esPrestador = r.esPrestador;
    final (bgAvatar, fgAvatar) = colorAvatar(r.autorNombre);
    final st = context.watch<AppState>();
    final esMiRespuesta = st.uid != null && st.uid == r.autorId;

    // Texto limpio sin prefijo redundante
    String textoLimpio = r.contenido;
    if (textoLimpio.startsWith('↳ @') && textoLimpio.contains(': ')) {
      textoLimpio = textoLimpio.substring(textoLimpio.indexOf(': ') + 2);
    }

    return Container(
      margin: EdgeInsets.only(bottom: esHija ? 8 : 0),
      padding: EdgeInsets.all(esHija ? 10 : 0),
      decoration: esHija
          ? BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabecera profesional: Avatar + Nombre + Badges + Sector/Tiempo + Like/Eliminar
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AvatarVecino(
                nombre: r.autorNombre,
                fotoUrl: r.autorFotoUrl,
                tamano: esHija ? 30 : 36,
                colorFondo: esPrestador ? Paleta.acentoSuave : bgAvatar,
                colorTexto: esPrestador ? Paleta.acentoOscuro : fgAvatar,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            r.autorNombre,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: esHija ? 13 : 14,
                              color: Paleta.tinta,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeRolAutor(r.autorRol) != null) ...[
                          const SizedBox(width: 5),
                          badgeRolAutor(r.autorRol)!,
                        ],
                        if (esPrestador) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Paleta.acentoSuave,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.handyman, size: 9, color: Paleta.acentoOscuro),
                                const SizedBox(width: 2.5),
                                Text(
                                  r.autorOficio ?? 'Prestador',
                                  style: const TextStyle(
                                    color: Paleta.acentoOscuro,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (r.sector != null && r.sector!.isNotEmpty) r.sector!,
                        r.tiempoRelativo,
                      ].join(' · '),
                      style: const TextStyle(
                        color: Paleta.gris,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (esMiRespuesta)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 17, color: Paleta.grisClaro),
                  tooltip: 'Eliminar comentario',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: onEliminar,
                ),
              InkWell(
                onTap: onLike,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        r.likePorUsuario ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                        size: 16,
                        color: r.likePorUsuario ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                      ),
                      if (r.likes > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${r.likes}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: r.likePorUsuario ? const Color(0xFF2563EB) : Paleta.gris,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: onDislike,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        r.dislikePorUsuario ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined,
                        size: 16,
                        color: r.dislikePorUsuario ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                      ),
                      if (r.dislikes > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${r.dislikes}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: r.dislikePorUsuario ? const Color(0xFFDC2626) : Paleta.gris,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 2. Indicador "Respuesta a @Usuario"
          if (r.respondiendoA != null && r.respondiendoA!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.reply_rounded, size: 12, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    'Respuesta a @${r.respondiendoA}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // 3. Texto del comentario
          Text(
            textoLimpio,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF334155),
              height: 1.45,
            ),
          ),

          // 4. Tarjeta opcional de contacto recomendado
          if (r.contactoTelefono != null && r.contactoTelefono!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Material(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => llamar(r.contactoTelefono!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_outlined, size: 15, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${r.nombreComercial ?? 'Prestador recomendado'}: ${_formatearCelularPeru(r.contactoTelefono!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.call, size: 11, color: Colors.white),
                            SizedBox(width: 3),
                            Text('Llamar', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // 5. Botón Responder alineado a la derecha
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onResponder,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.reply_rounded, size: 13, color: Paleta.primario),
                    SizedBox(width: 4),
                    Text(
                      'Responder',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Paleta.primario,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
