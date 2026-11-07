import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';
import '../util.dart';
import 'auth_screen.dart';

String traducirError(Object e) {
  if (e is PostgrestException) {
    if (e.code == '23505') return 'Esto ya estaba registrado.';
    if (e.code == '42501' || e.message.contains('row-level security')) {
      return 'No tienes permiso para hacer esto.';
    }
    return 'El servidor rechazó la acción: ${e.message}';
  }
  return 'Ocurrió un problema. Revisa tu conexión e intenta otra vez.';
}

/// Confirma y elimina (autor o moderador). Devuelve true si se eliminó.
Future<bool> confirmarEliminar(BuildContext context, AppState st, String tabla, String id, {required bool esModeracion}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.delete_forever, size: 40),
      title: Text(esModeracion ? '¿Eliminar por moderación?' : '¿Eliminar tu publicación?'),
      content: Text(esModeracion
          ? 'Úsalo para contenido falso, ofensivo o spam. Desaparecerá para todo el barrio.'
          : 'Desaparecerá para todos tus vecinos.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await st.repo.eliminar(tabla, id);
    avisar('Eliminado');
    st.refrescar();
    return true;
  } catch (e) {
    avisar(traducirError(e));
    return false;
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.icono, this.titulo, this.valor);
  final IconData icono;
  final String titulo;
  final String? valor;

  @override
  Widget build(BuildContext context) {
    if (valor == null || valor!.trim().isEmpty) return const SizedBox.shrink();
    return ListTile(leading: Icon(icono), title: Text(titulo), subtitle: Text(valor!, style: const TextStyle(fontSize: 16)));
  }
}

// =================================================== Servicio + Visto Bueno

class ServicioDetalle extends StatefulWidget {
  const ServicioDetalle({super.key, required this.servicio});
  final Servicio servicio;

  @override
  State<ServicioDetalle> createState() => _ServicioDetalleState();
}

class _ServicioDetalleState extends State<ServicioDetalle> {
  int _recarga = 0;

  Future<void> _darVistoBueno(AppState st) async {
    if (!st.logueado) {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => const AuthScreen(mensaje: 'Para dar tu Visto Bueno necesitas una cuenta de vecino.'),
      ));
      return;
    }
    final comentario = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Dar mi Visto Bueno'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Recomiéndalo solo si lo contrataste y quedaste conforme.'),
          const SizedBox(height: 12),
          TextField(
            controller: comentario,
            maxLength: 280,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Comentario (opcional)', hintText: 'Ej: Llegó puntual y cobró justo'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton.icon(onPressed: () => Navigator.pop(c, true), icon: const Icon(Icons.thumb_up), label: const Text('Recomendar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await st.repo.darVistoBueno(widget.servicio.id, comentario.text);
      avisar('¡Gracias! Tu Visto Bueno ayuda a tus vecinos');
      setState(() => _recarga++);
      st.refrescar();
    } catch (e) {
      final ya = e is PostgrestException && e.code == '23505';
      avisar(ya ? 'Ya diste tu Visto Bueno a este servicio' : traducirError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final s = widget.servicio;
    final cat = buscarCategoria(s.categoria, emergencia: s.esEmergencia);
    final esMio = s.autorId != null && s.autorId == st.uid;
    final dist = s.punto == null ? null : distanciaKm(st.referencia, s.punto!);

    return Scaffold(
      appBar: AppBar(title: Text(cat.nombre)),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.titulo, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(s.autorNombre ?? 'Vecino', style: Theme.of(context).textTheme.titleMedium),
              InsigniaRol(s.autorRol),
            ]),
            BotonEscuchar(s.textoParaVoz),
          ]),
        ),
        if (s.telefono != null && s.telefono!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: FilledButton.icon(onPressed: () => llamar(s.telefono!), icon: const Icon(Icons.call), label: const Text('Llamar'))),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => abrirWhatsapp(s.telefono!, 'Hola, te encontré en App Vecinal: "${s.titulo}"'),
                  icon: const Icon(Icons.chat),
                  label: const Text('WhatsApp'),
                ),
              ),
            ]),
          ),
        _Dato(Icons.description, 'Descripción', s.descripcion),
        _Dato(Icons.payments, 'Precio referencial', s.precioRef),
        _Dato(Icons.schedule, 'Horario', s.horario),
        _Dato(Icons.place, 'Zona', [?s.sector, if (dist != null) formatoDistancia(dist)].join(' · ')),
        const Divider(),
        TituloSeccion('Visto Bueno Vecinal (${s.vistosBuenos})'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Recomendaciones de vecinos que ya usaron este servicio.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        if (!esMio && !s.pendiente)
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.tonalIcon(
              onPressed: () => _darVistoBueno(st),
              icon: const Icon(Icons.thumb_up),
              label: const Text('Dar mi Visto Bueno'),
            ),
          ),
        Cargador<List<VistoBueno>>(
          claves: [s.id, _recarga],
          cargar: (st) => st.repo.vistosBuenos(s.id),
          builder: (c, lista) {
            if (lista.isEmpty) {
              return const EstadoVacio(icono: Icons.thumb_up_off_alt, texto: 'Aún nadie lo recomienda. ¡Sé el primero si lo usaste!');
            }
            final verificados = lista.where((v) => v.verificado).length;
            return Column(children: [
              if (verificados > 0)
                ListTile(
                  leading: const Icon(Icons.verified_user, color: Color(0xFF2E7D32), size: 32),
                  title: Text('$verificados de ${lista.length} son vecinos verificados de ${Zona.nombre}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Confirmaron con GPS que viven en la zona'),
                ),
              for (final vb in lista)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: vb.verificado ? const Color(0xFFC8E6C9) : null,
                    child: Icon(vb.verificado ? Icons.verified_user : Icons.thumb_up, size: 20,
                        color: vb.verificado ? const Color(0xFF1B5E20) : null),
                  ),
                  title: Text([vb.autorNombre ?? 'Vecino', if (vb.verificado) '· vecino verificado'].join(' ')),
                  subtitle: Text([?vb.comentario, haceCuanto(vb.creado)].join('\n')),
                ),
            ]);
          },
        ),
        if (!s.pendiente && (esMio || st.esModerador))
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB71C1C)),
              onPressed: () async {
                final ok = await confirmarEliminar(context, st, 'servicios', s.id, esModeracion: !esMio);
                if (ok && context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline),
              label: Text(esMio ? 'Eliminar mi publicación' : 'Eliminar (moderación)'),
            ),
          ),
      ]),
    );
  }
}

// ======================================================= Publicación

/// Detalle de un favor, pedido de ayuda o recurso, con coordinación vecinal:
/// "Yo ayudo" (cualquier vecino), "La atendemos" (organización),
/// "Resuelto" (autor/organización/moderador) y eliminar (autor/moderador).
class PublicacionDetalle extends StatefulWidget {
  const PublicacionDetalle({super.key, required this.publicacion});
  final Publicacion publicacion;

  @override
  State<PublicacionDetalle> createState() => _PublicacionDetalleState();
}

class _PublicacionDetalleState extends State<PublicacionDetalle> {
  int _recarga = 0;
  bool _ocupado = false;

  Publicacion get p => widget.publicacion;

  Future<void> _cambiar(AppState st, String estado, {bool atender = false}) async {
    setState(() => _ocupado = true);
    try {
      await st.repo.cambiarEstado(p.id, estado, atender: atender);
      avisar(estado == 'resuelta' ? '¡Marcado como resuelto! Gracias por ayudar.' : 'Listo: tu organización lo atiende');
      st.refrescar();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      avisar(traducirError(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _yoAyudo(AppState st, bool yaAyudo) async {
    if (!st.logueado) {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => const AuthScreen(mensaje: 'Para comprometerte a ayudar necesitas una cuenta de vecino.'),
      ));
      return;
    }
    setState(() => _ocupado = true);
    try {
      if (yaAyudo) {
        await st.repo.retirarAyuda(p.id);
        avisar('Quitaste tu compromiso de ayuda');
      } else {
        await st.repo.ofrecerAyuda(p.id);
        avisar('¡Gracias! ${p.autorVisible} verá que vas a ayudar. Coordina por llamada o WhatsApp.');
      }
      setState(() => _recarga++);
      st.refrescar();
    } catch (e) {
      avisar(traducirError(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final cat = buscarCategoria(p.categoria, emergencia: p.esEmergencia);
    final esMio = p.autorId != null && p.autorId == st.uid;
    final esOrg = st.esOrganizacion || st.esModerador;
    final dist = p.punto == null ? null : distanciaKm(st.referencia, p.punto!);
    final tel = p.contactoTelefono;

    return Scaffold(
      appBar: AppBar(title: Text(p.esPedido ? 'Pedido' : 'Ofrecimiento')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Chip(avatar: Icon(cat.icono), label: Text(cat.nombre)),
            Text(p.titulo, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(p.autorVisible, style: Theme.of(context).textTheme.titleMedium),
              InsigniaRol(p.autorRol),
            ]),
            BotonEscuchar(p.textoParaVoz),
          ]),
        ),
        if (tel != null && tel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => llamar(tel),
                  icon: const Icon(Icons.call),
                  label: const Text('Llamar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => abrirWhatsapp(tel, 'Hola, vi en App Vecinal: "${p.titulo}". ¿Cómo puedo ayudarte?'),
                  icon: const Icon(Icons.chat),
                  label: const Text('WhatsApp'),
                ),
              ),
            ]),
          ),
        _Dato(Icons.description, 'Detalle', p.descripcion),
        _Dato(Icons.groups, 'Personas', p.personas?.toString()),
        _Dato(Icons.place, 'Ubicación', [?p.sector, if (dist != null) formatoDistancia(dist)].join(' · ')),
        _Dato(Icons.schedule, 'Publicado', haceCuanto(p.creado)),
        _Dato(Icons.flag, 'Estado', switch (p.estado) {
          'en_curso' => 'Ya están ayudando',
          'resuelta' => 'Resuelto',
          _ => 'Esperando ayuda',
        }),
        if (p.origen == 'qr')
          const _Dato(Icons.qr_code_2, 'Cómo llegó', 'Un vecino trajo este pedido por código QR porque no tenía internet.'),
        if (p.pendiente)
          const _Dato(Icons.schedule_send, 'Aún no enviado', 'Se publicará apenas haya internet.'),

        // ----------------------------------------- coordinación vecinal
        if (!p.pendiente && p.esPedido && p.estado != 'resuelta') ...[
          const Divider(),
          const TituloSeccion('Vecinos que van a ayudar'),
          Cargador<List<Ayuda>>(
            claves: [p.id, _recarga],
            cargar: (st) => st.repo.ayudas(p.id),
            builder: (c, lista) {
              final yaAyudo = lista.any((a) => a.vecinoId == st.uid);
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (lista.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Nadie se ha comprometido todavía. ¿Puedes ayudar?', style: TextStyle(fontSize: 16)),
                  )
                else
                  for (final a in lista)
                    ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.volunteer_activism, size: 20)),
                      title: Text(a.vecinoId == st.uid ? 'Tú' : (a.vecinoNombre ?? 'Vecino')),
                      subtitle: Text('Se comprometió ${haceCuanto(a.creado)}'),
                    ),
                if (!esMio)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 56,
                      child: yaAyudo
                          ? OutlinedButton.icon(
                              onPressed: _ocupado ? null : () => _yoAyudo(st, true),
                              icon: const Icon(Icons.undo),
                              label: const Text('Ya no puedo ayudar'),
                            )
                          : FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                              onPressed: _ocupado ? null : () => _yoAyudo(st, false),
                              icon: const Icon(Icons.volunteer_activism),
                              label: const Text('Yo ayudo', style: TextStyle(fontSize: 18)),
                            ),
                    ),
                  ),
              ]);
            },
          ),
        ],

        if (!p.pendiente && (esOrg || esMio)) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (esOrg && p.esEmergencia && p.estado == 'abierta')
                FilledButton.icon(
                  onPressed: _ocupado ? null : () => _cambiar(st, 'en_curso', atender: true),
                  icon: const Icon(Icons.health_and_safety),
                  label: const Text('Nuestra organización lo atiende'),
                ),
              if (p.estado != 'resuelta') ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _ocupado ? null : () => _cambiar(st, 'resuelta'),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Marcar como resuelto'),
                ),
              ],
            ]),
          ),
        ],
        if (!p.pendiente && (esMio || st.esModerador))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB71C1C)),
              onPressed: () async {
                final ok = await confirmarEliminar(context, st, 'publicaciones', p.id, esModeracion: !esMio);
                if (ok && context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline),
              label: Text(esMio ? 'Eliminar mi publicación' : 'Eliminar (moderación)'),
            ),
          ),
      ]),
    );
  }
}

