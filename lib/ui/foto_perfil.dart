import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'diseno.dart';
import 'tema.dart';

/// Foto del vecino en un círculo. Si no tiene foto (o no hay internet para
/// cargarla) muestra sus iniciales.
class AvatarVecino extends StatelessWidget {
  const AvatarVecino({
    super.key,
    required this.nombre,
    this.fotoUrl,
    this.tamano = 56,
    this.colorFondo,
    this.colorTexto,
  });
  final String nombre;
  final String? fotoUrl;
  final double tamano;
  final Color? colorFondo;
  final Color? colorTexto;

  @override
  Widget build(BuildContext context) {
    final color = colorFondo ?? Theme.of(context).colorScheme.primary;
    final txtColor = colorTexto ?? Colors.white;
    final letras = Center(
      child: Text(
        iniciales(nombre),
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: txtColor,
          fontSize: tamano * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Semantics(
      image: true,
      label: fotoUrl == null ? 'Iniciales de $nombre' : 'Foto de $nombre',
      excludeSemantics: true,
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        clipBehavior: Clip.antiAlias,
        child: fotoUrl == null
            ? letras
            : Image.network(
                fotoUrl!,
                fit: BoxFit.cover,
                width: tamano,
                height: tamano,
                errorBuilder: (_, _, _) => letras,
                loadingBuilder: (_, child, progreso) => progreso == null ? child : letras,
              ),
      ),
    );
  }
}

/// Menú grande y claro para poner, cambiar o quitar la foto de perfil.
Future<void> cambiarFotoPerfil(BuildContext context) async {
  final st = context.read<AppState>();
  if (!st.online) {
    avisar('Necesitas internet para cambiar tu foto.');
    return;
  }
  final opcion = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(
            header: true,
            child: const Text('Tu foto de perfil', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          const Text('Así tus vecinos te reconocen cuando publicas o ayudas.',
              style: TextStyle(color: Paleta.gris, fontSize: 15)),
          const SizedBox(height: 16),
          _OpcionFoto(icono: Icons.photo_camera, texto: 'Tomar una foto', onTap: () => Navigator.pop(c, 'camara')),
          const SizedBox(height: 10),
          _OpcionFoto(icono: Icons.photo_library, texto: 'Elegir de mi galería', onTap: () => Navigator.pop(c, 'galeria')),
          if (st.fotoUrl != null) ...[
            const SizedBox(height: 10),
            _OpcionFoto(
              icono: Icons.delete_outline,
              texto: 'Quitar mi foto',
              color: Paleta.rojo,
              onTap: () => Navigator.pop(c, 'quitar'),
            ),
          ],
        ]),
      ),
    ),
  );
  if (opcion == null || !context.mounted) return;

  if (opcion == 'quitar') {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Quitar tu foto?'),
        content: const Text('Se mostrarán tus iniciales en su lugar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Quitar')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await _conEspera(context, () async {
      await st.repo.quitarFotoPerfil();
      await st.cargarPerfil();
    }, 'Listo, quitamos tu foto.');
    return;
  }

  XFile? archivo;
  try {
    archivo = await ImagePicker().pickImage(
      source: opcion == 'camara' ? ImageSource.camera : ImageSource.gallery,
      preferredCameraDevice: CameraDevice.front,
      // Foto liviana: carga rápido aunque la señal sea mala.
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 80,
    );
  } catch (_) {
    avisar(opcion == 'camara'
        ? 'No pudimos abrir la cámara. Revisa que la app tenga permiso de cámara.'
        : 'No pudimos abrir tu galería. Revisa que la app tenga permiso de fotos.');
    return;
  }
  if (archivo == null || !context.mounted) return;
  final bytes = await archivo.readAsBytes();
  if (!context.mounted) return;

  // Vista previa: confirmar antes de subir (evita fotos por error).
  final usar = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('¿Usar esta foto?', textAlign: TextAlign.center),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipOval(child: Image.memory(bytes, width: 180, height: 180, fit: BoxFit.cover)),
        const SizedBox(height: 12),
        const Text('Tus vecinos verán esta foto en tu perfil.', textAlign: TextAlign.center),
      ]),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Elegir otra')),
        FilledButton.icon(
          onPressed: () => Navigator.pop(c, true),
          icon: const Icon(Icons.check),
          label: const Text('Usar foto'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  if (usar != true) {
    // "Elegir otra": vuelve a abrir el menú.
    if (usar == false) await cambiarFotoPerfil(context);
    return;
  }
  await _conEspera(context, () async {
    await st.repo.subirFotoPerfil(bytes, _tipo(archivo!));
    await st.cargarPerfil();
  }, '¡Listo! Tu foto ya está en tu perfil.');
}

String _tipo(XFile f) {
  final m = f.mimeType;
  if (m != null && m.startsWith('image/')) return m;
  final n = f.name.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

/// Muestra "Guardando..." mientras sube, y un mensaje claro al terminar.
Future<void> _conEspera(BuildContext context, Future<void> Function() tarea, String exito) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          SizedBox(width: 18),
          Expanded(child: Text('Guardando tu foto...', style: TextStyle(fontSize: 17))),
        ]),
      ),
    ),
  );
  var ok = true;
  try {
    await tarea();
  } catch (_) {
    ok = false;
  }
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  avisar(ok ? exito : 'No se pudo guardar la foto. Revisa tu internet e inténtalo otra vez.');
}

class _OpcionFoto extends StatelessWidget {
  const _OpcionFoto({required this.icono, required this.texto, required this.onTap, this.color});
  final IconData icono;
  final String texto;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Material(
      color: c.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Icon(icono, color: c, size: 28),
              const SizedBox(width: 14),
              Expanded(child: Text(texto, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c))),
              Icon(Icons.chevron_right, color: c),
            ]),
          ),
        ),
      ),
    );
  }
}
