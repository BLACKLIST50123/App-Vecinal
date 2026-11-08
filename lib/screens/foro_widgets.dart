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
  const paletas = [
    (Color(0xFFFEE2E2), Color(0xFFDC2626)), // Coral / Rojo
    (Color(0xFFFFF7ED), Color(0xFFEA580C)), // Naranja cálido
    (Color(0xFFFEFCE8), Color(0xFFCA8A04)), // Ámbar
    (Color(0xFFECFDF5), Color(0xFF059669)), // Esmeralda
    (Color(0xFFF0FDF4), Color(0xFF16A34A)), // Verde
    (Color(0xFFF0FDFA), Color(0xFF0D9488)), // Turquesa
    (Color(0xFFF0F9FF), Color(0xFF0284C7)), // Celeste
    (Color(0xFFEEF2FF), Color(0xFF4F46E5)), // Índigo
    (Color(0xFFFAF5FF), Color(0xFF9333EA)), // Púrpura
  ];
  final hash = nombre.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
  return paletas[hash % paletas.length];
}

/// Distintivo de rol comunitario (Brigadista o Líder).
Widget? badgeRolAutor(String? rol) {
  if (rol == null || rol == 'vecino' || rol.isEmpty) return null;
  final (texto, icono, color) = switch (rol.toLowerCase()) {
    'brigadista' => (
        'Brigadista',
        Icons.health_and_safety_outlined,
        const Color(0xFFC62828),
      ),
    'lider' || 'lider_comunitario' => (
        'Líder Comunitario',
        Icons.shield_outlined,
        const Color(0xFF1565C0),
      ),
    _ => (
        rol[0].toUpperCase() + rol.substring(1),
        Icons.verified_user_outlined,
        const Color(0xFF0369A1),
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

/// Tarjeta estructurada de una publicación en el foro vecinal.
/// Usa borde uniforme y clip para franja izquierda sin causar fallas en Flutter Web.
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
            // Franja lateral con el color de la categoría
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
                        // Cabecera: Autor, Sector, Badges y Menú
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
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
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (tema.estado == 'resuelto') ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
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
                                    Icon(Icons.check_circle, size: 11, color: Color(0xFF16A34A)),
                                    SizedBox(width: 3),
                                    Text(
                                      'Resuelto',
                                      style: TextStyle(
                                        color: Color(0xFF166534),
                                        fontSize: 10,
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
                            color: Color(0xFF334155),
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
                                          ? const Color(0xFF2E7D32)
                                          : Paleta.gris,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${tema.apoyos}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: tema.apoyadoPorUsuario
                                            ? const Color(0xFF2E7D32)
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
                                const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 16,
                                  color: Paleta.gris,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${tema.respuestasCount} ${tema.respuestasCount == 1 ? 'respuesta' : 'respuestas'}',
                                  style: const TextStyle(
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

/// Tarjeta de respuesta en una conversación con soporte para recomendaciones y llamadas.
class TarjetaRespuesta extends StatelessWidget {
  const TarjetaRespuesta({
    super.key,
    required this.r,
    required this.onEliminar,
  });

  final RespuestaForo r;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final esPrestador = r.esPrestador;
    final (bgAvatar, fgAvatar) = colorAvatar(r.autorNombre);
    final st = context.watch<AppState>();
    final esMiRespuesta = st.uid != null && st.uid == r.autorId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esPrestador
              ? Paleta.acento.withValues(alpha: 0.4)
              : Paleta.linea,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 17,
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
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            r.autorNombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Paleta.tinta,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeRolAutor(r.autorRol) != null) ...[
                          const SizedBox(width: 4),
                          badgeRolAutor(r.autorRol)!,
                        ],
                        const Spacer(),
                        if (esPrestador && r.vistosBuenos > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.thumb_up_alt_rounded,
                                  size: 11,
                                  color: Color(0xFF2E7D32),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${r.vistosBuenos} Vistos Buenos',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (esMiRespuesta) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: Paleta.grisClaro,
                            ),
                            tooltip: 'Eliminar mi respuesta',
                            onPressed: onEliminar,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (esPrestador)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Paleta.acentoSuave,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.handyman,
                                  size: 10,
                                  color: Paleta.acentoOscuro,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  r.autorOficio ?? 'Prestador',
                                  style: const TextStyle(
                                    color: Paleta.acentoOscuro,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Text(
                          [
                            if (r.sector != null) r.sector!,
                            r.tiempoRelativo,
                          ].join(' · '),
                          style: const TextStyle(
                            color: Paleta.gris,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            r.contenido,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF334155),
              height: 1.4,
            ),
          ),
          if (r.contactoTelefono != null) ...[
            const SizedBox(height: 10),
            Material(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => llamar(r.contactoTelefono!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 16,
                        color: Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${r.nombreComercial ?? 'Contacto'}: ${r.contactoTelefono}',
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
                            Text(
                              'Llamar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
