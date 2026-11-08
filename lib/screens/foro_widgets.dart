import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/diseno.dart';
import '../ui/tema.dart';
import '../ui/widgets.dart';

/// Paleta armónica para avatares vecinales con vida y color.
(Color, Color) colorAvatar(String nombre) {
  final paletas = [
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
  });

  final TemaForo tema;
  final VoidCallback onTap;
  final VoidCallback onApoyar;

  @override
  Widget build(BuildContext context) {
    final (nombreTipo, iconoTipo, colorTipo, fondoTipo) = tema.datosTipo;
    final (bgAvatar, fgAvatar) = colorAvatar(tema.autorNombre);
    final st = context.watch<AppState>();
    final esMiTema = st.uid != null && st.uid == tema.autorId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: Paleta.superficie,
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
                            CircleAvatar(
                              radius: 19,
                              backgroundColor: bgAvatar,
                              child: Text(
                                iniciales(tema.autorNombre),
                                style: TextStyle(
                                  color: fgAvatar,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
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
                                          style: TextStyle(
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
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 13,
                                        color: Paleta.gris,
                                      ),
                                      const SizedBox(width: 2),
                                      Expanded(
                                        child: Text(
                                          '${tema.sector} · ${tema.tiempoRelativo}',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
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
                                      color: Paleta.verdeSuave,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF86EFAC)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle, size: 10, color: Paleta.verde),
                                        SizedBox(width: 2.5),
                                        Text(
                                          'Resuelto',
                                          style: TextStyle(
                                            color: Paleta.verde,
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
                                    icon: Icon(Icons.more_vert, size: 18, color: Paleta.gris),
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
                                              color: Paleta.verde,
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
                                      PopupMenuItem(
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
                          style: TextStyle(
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
                          style: TextStyle(
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
                                Icon(
                                  Icons.handyman_outlined,
                                  size: 14,
                                  color: Paleta.acentoOscuro,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Oficio requerido: ${buscarCategoria(tema.categoriaServicio!).nombre}',
                                  style: TextStyle(
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
                        Divider(height: 1, color: Paleta.linea),
                        const SizedBox(height: 10),

                        // Pie de tarjeta
                        Row(
                          children: [
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
                                      color: tema.apoyadoPorUsuario
                                          ? Paleta.verde
                                          : Paleta.gris,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${tema.apoyos}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: tema.apoyadoPorUsuario
                                            ? Paleta.verde
                                            : Paleta.gris,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Row(
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 16,
                                  color: Paleta.gris,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${tema.respuestasCount} ${tema.respuestasCount == 1 ? 'respuesta' : 'respuestas'}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Paleta.gris,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Text(
                                  tema.tipo == TipoPublicacionForo.servicio
                                      ? 'Recomendar'
                                      : 'Conversar',
                                  style: TextStyle(
                                    color: Paleta.primario,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Icon(
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

/// Tarjeta de respuesta optimizada, limpia y con opción para responder a un usuario específico.
class TarjetaRespuesta extends StatelessWidget {
  const TarjetaRespuesta({
    super.key,
    required this.r,
    required this.onEliminar,
    required this.onResponder,
  });

  final RespuestaForo r;
  final VoidCallback onEliminar;
  final VoidCallback onResponder;

  @override
  Widget build(BuildContext context) {
    final esPrestador = r.esPrestador;
    final (bgAvatar, fgAvatar) = colorAvatar(r.autorNombre);
    final st = context.watch<AppState>();
    final esMiRespuesta = st.uid != null && st.uid == r.autorId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Paleta.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esPrestador
              ? Paleta.acento.withValues(alpha: 0.35)
              : Paleta.linea,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera compacta y bien proporcionada
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: esPrestador ? Paleta.acentoSuave : bgAvatar,
                child: Text(
                  iniciales(r.autorNombre),
                  style: TextStyle(
                    color: esPrestador ? Paleta.acentoOscuro : fgAvatar,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
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
                              fontSize: 14,
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
                                Icon(Icons.handyman, size: 9, color: Paleta.acentoOscuro),
                                const SizedBox(width: 2.5),
                                Text(
                                  r.autorOficio ?? 'Prestador',
                                  style: TextStyle(
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
                      style: TextStyle(
                        color: Paleta.gris,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (esMiRespuesta)
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 18, color: Paleta.grisClaro),
                  tooltip: 'Eliminar mi respuesta',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEliminar,
                ),
            ],
          ),

          // Indicador "Respuesta a @Usuario"
          if (r.respondiendoA != null && r.respondiendoA!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: Paleta.grisFondo,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Paleta.linea),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.reply_rounded, size: 12, color: Paleta.gris),
                  const SizedBox(width: 4),
                  Text(
                    'Respuesta a @${r.respondiendoA}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Paleta.gris,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 9),

          // Texto de la respuesta
          Text(
            r.contenido.startsWith('↳ @') && r.contenido.contains(': ')
                ? r.contenido.substring(r.contenido.indexOf(': ') + 2)
                : r.contenido,
            style: TextStyle(
              fontSize: 14,
              color: Paleta.primarioClaro,
              height: 1.45,
            ),
          ),

          // Tarjeta de recomendación de contacto
          if (r.contactoTelefono != null && r.contactoTelefono!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Material(
              color: Paleta.verdeSuave,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => llamar(r.contactoTelefono!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Paleta.verdeSuave,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.phone_outlined, size: 16, color: Paleta.verde),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.nombreComercial ?? 'Prestador recomendado',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Paleta.verde,
                              ),
                            ),
                            Text(
                              r.contactoTelefono!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Paleta.verde,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Paleta.verde,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => llamar(r.contactoTelefono!),
                        icon: const Icon(Icons.call, size: 13),
                        label: const Text('Llamar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          // Botón para responder a este comentario
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onResponder,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.reply_rounded, size: 14, color: Paleta.primario),
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
