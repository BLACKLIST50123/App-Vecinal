import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/tema.dart';
import '../ui/widgets.dart';
import '../util.dart';
import 'auth_screen.dart';
import 'confianza.dart';

String traducirError(Object e) {
  if (e is SinPermiso) return e.mensaje;
  if (e is PostgrestException) {
    if (e.code == 'P0001') return e.message; // mensajes propios del servidor (anti-spam)
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
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
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
      appBar: AppBar(title: Text(cat.nombre), actions: [
        IconButton(
          tooltip: 'Compartir por WhatsApp',
          icon: const Icon(Icons.share),
          onPressed: () => compartirWhatsapp(
              'Te recomiendo "${s.titulo}"${s.sector != null ? ' en ${s.sector}' : ''}, '
              '${s.vistosBuenos} vecinos le dieron su Visto Bueno en Conecta Vecino ${Zona.nombre}.'),
        ),
        if (!esMio && !s.pendiente)
          IconButton(
            tooltip: 'Reportar',
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => reportarContenido(context, tabla: 'servicios', id: s.id, titulo: s.titulo),
          ),
      ]),
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
        if (!esMio && !s.pendiente && s.autorId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Paleta.acentoOscuro,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => ModalSolicitarPedido(servicio: s),
              ),
              icon: const Icon(Icons.send_outlined),
              label: const Text('Solicitar servicio / Hacer pedido',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        if (esMio)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Paleta.acentoSuave,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Paleta.acentoOscuro.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Paleta.acentoOscuro),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Esta es tu publicación. Puedes ver pedidos y editarla en "Mis aportes".',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Paleta.acentoOscuro),
                  ),
                ),
              ],
            ),
          ),
        if (s.telefono != null && s.telefono!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: FilledButton.icon(onPressed: () => llamar(s.telefono!), icon: const Icon(Icons.call), label: const Text('Llamar'))),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => abrirWhatsapp(s.telefono!, 'Hola, te encontré en Conecta Vecino: "${s.titulo}"'),
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
          child: Text('Experiencias de vecinos que ya lo usaron. No es una certificación profesional.',
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
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFE53935)),
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

class ModalSolicitarPedido extends StatefulWidget {
  const ModalSolicitarPedido({super.key, required this.servicio});
  final Servicio servicio;

  @override
  State<ModalSolicitarPedido> createState() => _ModalSolicitarPedidoState();
}

class _ModalSolicitarPedidoState extends State<ModalSolicitarPedido> {
  final _detalle = TextEditingController();
  final _fecha = TextEditingController();
  final _telefono = TextEditingController();
  String? _sector;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    final st = context.read<AppState>();
    final tel = st.perfil?['telefono'] as String?;
    if (tel != null) _telefono.text = tel;
    _sector = st.sector;
  }

  @override
  void dispose() {
    _detalle.dispose();
    _fecha.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final st = context.read<AppState>();
    if (!st.logueado) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthScreen(mensaje: 'Para hacer un pedido necesitas una cuenta de vecino.'),
        ),
      );
      return;
    }
    final detalle = _detalle.text.trim();
    if (detalle.length < 2) {
      avisar('Escribe qué necesitas o qué deseas pedir.');
      return;
    }
    if (widget.servicio.autorId == null) {
      avisar('No se puede enviar pedido a este servicio.');
      return;
    }
    setState(() => _enviando = true);
    final id = nuevoId();
    final pedido = PedidoServicio(
      id: id,
      servicioId: widget.servicio.id,
      prestadorId: widget.servicio.autorId!,
      clienteId: st.uid,
      clienteNombre: st.nombre,
      clienteTelefono: _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
      clienteSector: _sector,
      detalle: detalle,
      fechaDeseada: _fecha.text.trim().isEmpty ? null : _fecha.text.trim(),
      estado: 'pendiente',
    );
    try {
      await st.repo.crearPedidoServicio(pedido.toInsert());
      if (mounted) {
        Navigator.pop(context);
        avisar('¡Pedido enviado al prestador!');
        st.refrescar();
        final telPrestador = widget.servicio.telefono;
        if (telPrestador != null && telPrestador.isNotEmpty) {
          final wsp = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 36),
              title: const Text('¿Avisarle también por WhatsApp?'),
              content: const Text(
                  'Le hemos guardado el pedido en la app. ¿Deseas abrir WhatsApp para escribirle de una vez?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Solo en la app')),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(c, true),
                  icon: const Icon(Icons.chat),
                  label: const Text('Abrir WhatsApp'),
                ),
              ],
            ),
          );
          if (wsp == true) {
            final msg =
                'Hola ${widget.servicio.autorNombre ?? ''}, te solicité "${widget.servicio.titulo}" en App Vecinal: "$detalle". ¿Tienes disponibilidad?';
            abrirWhatsapp(telPrestador, msg);
          }
        }
      }
    } catch (e) {
      if (mounted) avisar(traducirError(e));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 20,
          right: 20,
          top: 8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: Paleta.acentoSuave, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.send_outlined, color: Paleta.acentoOscuro),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hacer pedido / Solicitud',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(widget.servicio.titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Paleta.gris, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _detalle,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '¿Qué necesitas o qué deseas pedir? *',
                  hintText: 'Ej. Reparar fuga de agua en el lavadero / 1 torta para el sábado',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fecha,
                decoration: const InputDecoration(
                  labelText: '¿Para cuándo lo necesitas? (opcional)',
                  hintText: 'Ej. Mañana a las 10 am / Lo antes posible',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _telefono,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Tu teléfono de contacto',
                  hintText: 'Para que el prestador te llame o escriba',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _sector,
                decoration: const InputDecoration(labelText: 'Tu sector en el barrio'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No especificar')),
                  for (final s in Zona.sectores.keys) DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() => _sector = v),
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Paleta.acentoOscuro,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: _enviando ? null : _enviar,
                child: Text(_enviando ? 'Enviando pedido...' : 'Enviar pedido al prestador'),
              ),
            ],
          ),
        ),
      ),
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
      avisar(estado == 'resuelta'
          ? (p.esColecta
              ? '¡Qué bien! La colecta quedó cerrada. Gracias a todos los que aportaron.'
              : (p.esPedido ? '¡Qué bueno que ya te ayudaron! Gracias por confiar en tus vecinos.' : '¡Gracias por compartir! Ya quedó como entregado.'))
          : 'Listo: tu organización lo atiende');
      st.refrescar();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      avisar(traducirError(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Al cerrar un pedido o colecta propio, preguntar quién ayudó:
  /// ese agradecimiento es el que da reconocimiento al vecino.
  Future<void> _cerrar(AppState st) async {
    final esMio = p.autorId != null && p.autorId == st.uid;
    if (esMio && p.esPedido) {
      var respuestas = <Ayuda>[];
      try {
        respuestas = (await st.repo.ayudas(p.id)).where((a) => a.vecinoId != st.uid).toList();
      } catch (_) {}
      if (respuestas.isNotEmpty && mounted) {
        final elegidos = respuestas.map((a) => a.vecinoId).toSet();
        final mensaje = TextEditingController();
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => StatefulBuilder(
            builder: (c, setD) => AlertDialog(
              icon: const Icon(Icons.favorite, color: Color(0xFFC2185B), size: 40),
              title: Text(p.esColecta ? '¿Quiénes aportaron?' : '¿Quién te ayudó?'),
              content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Tu agradecimiento le da reconocimiento en el barrio.'),
                  const SizedBox(height: 8),
                  for (final a in respuestas)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: elegidos.contains(a.vecinoId),
                      onChanged: (v) => setD(() => v == true ? elegidos.add(a.vecinoId) : elegidos.remove(a.vecinoId)),
                      title: Text(a.vecinoNombre ?? 'Vecino'),
                      subtitle: InsigniaNivel(a.ayudasConfirmadas, mostrarSiCero: true),
                    ),
                  TextField(
                    controller: mensaje,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Mensaje de gracias (opcional)', hintText: 'Ej: ¡Mil gracias por venir tan rápido!'),
                  ),
                ]),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(c, true),
                  icon: const Icon(Icons.favorite),
                  label: Text(elegidos.isEmpty ? 'Cerrar sin agradecer' : 'Agradecer y cerrar'),
                ),
              ],
            ),
          ),
        );
        if (ok != true) return;
        try {
          await st.repo.agradecer(p.id, elegidos.toList(), mensaje: mensaje.text);
          if (elegidos.isNotEmpty) {
            avisar(elegidos.length == 1 ? 'Le enviaste tu agradecimiento.' : 'Les enviaste tu agradecimiento.');
          }
        } catch (e) {
          avisar(traducirError(e));
        }
      }
    }
    await _cambiar(st, 'resuelta');
  }

  Future<void> _verificar(AppState st, bool verificada) async {
    setState(() => _ocupado = true);
    try {
      await st.repo.verificar(p.id, verificada: verificada, estadoActual: p.estado);
      avisar(verificada ? 'Pedido verificado' : 'Marcado como no verificado');
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
        builder: (_) => const AuthScreen(mensaje: 'Para responder necesitas una cuenta de vecino. Es gratis y toma 1 minuto.'),
      ));
      return;
    }
    setState(() => _ocupado = true);
    try {
      if (yaAyudo) {
        await st.repo.retirarAyuda(p.id);
        avisar('Listo, ya no apareces en la lista. No pasa nada, gracias por avisar.');
        setState(() => _recarga++);
        st.refrescar();
      } else {
        await st.repo.ofrecerAyuda(p.id);
        setState(() => _recarga++);
        st.refrescar();
        if (mounted) await _siguientePaso();
      }
    } catch (e) {
      avisar(traducirError(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Después de responder, decirle al vecino qué hacer ahora.
  Future<void> _siguientePaso() {
    final tel = p.contactoTelefono;
    final titulo = p.esColecta
        ? '¡Gracias por aportar!'
        : (p.esPedido ? '¡Gracias por ayudar!' : '¡Le avisamos que te interesa!');
    final texto = p.esColecta
        ? 'Ahora ponte de acuerdo con ${p.autorVisible} para entregar tu donación. ${p.descripcion ?? ''}'
        : (p.esPedido
            ? '${p.autorVisible} verá que vas a ayudar. Ahora llámale o escríbele para ponerse de acuerdo.'
            : 'Ahora escríbele a ${p.autorVisible} para ponerse de acuerdo en cómo recogerlo.');
    return showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.favorite, color: Color(0xFFC2185B), size: 44),
        title: Text(titulo),
        content: Text(texto, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Después')),
          if (tel != null && tel.isNotEmpty) ...[
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(c);
                llamar(tel);
              },
              icon: const Icon(Icons.call),
              label: const Text('Llamar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(c);
                abrirWhatsapp(tel, 'Hola ${p.autorVisible}, te escribo por Conecta Vecino: "${p.titulo}". ${p.textoResponder == 'Yo aporto' ? 'Quiero aportar.' : (p.esPedido ? 'Puedo ayudarte.' : 'Me interesa.')}');
              },
              icon: const Icon(Icons.chat),
              label: const Text('WhatsApp'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _actualizarAvance(AppState st) async {
    var valor = p.avance;
    final nuevo = await showDialog<int>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('¿Cuántas donaciones ya recibiste en persona?'),
          content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton.filledTonal(onPressed: valor > 0 ? () => setD(() => valor--) : null, icon: const Icon(Icons.remove)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text('$valor', style: Theme.of(c).textTheme.headlineMedium)),
            IconButton.filledTonal(onPressed: () => setD(() => valor++), icon: const Icon(Icons.add)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, valor), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (nuevo == null) return;
    try {
      await st.repo.actualizarAvance(p.id, nuevo);
      avisar('Avance actualizado. ¡Sigan así!');
      st.refrescar();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      avisar(traducirError(e));
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
      appBar: AppBar(title: Text(p.esColecta ? 'Colecta' : (p.esPedido ? 'Necesita ayuda' : 'Ofrece')), actions: [
        if (!p.pendiente)
          IconButton(
            tooltip: 'Compartir por WhatsApp',
            icon: const Icon(Icons.share),
            onPressed: () => compartirWhatsapp(textoCompartir(p)),
          ),
        if (!esMio && !p.pendiente)
          IconButton(
            tooltip: 'Reportar',
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => reportarContenido(context, tabla: 'publicaciones', id: p.id, titulo: p.titulo),
          ),
      ]),
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
            if (p.esColecta && p.meta != null)
              Padding(padding: const EdgeInsets.only(top: 12), child: BarraColecta(p, grande: true)),
            BotonEscuchar(p.textoParaVoz),
          ]),
        ),

        // ------------------- acción principal + quiénes respondieron
        if (!p.pendiente && p.estado != 'resuelta')
          Cargador<List<Ayuda>>(
            claves: [p.id, _recarga],
            cargar: (st) => st.repo.ayudas(p.id),
            builder: (c, lista) {
              final yaRespondi = lista.any((a) => a.vecinoId == st.uid);
              final tituloLista = esMio
                  ? 'Vecinos que respondieron'
                  : (p.esColecta ? 'Vecinos que aportaron' : (p.esPedido ? 'Vecinos que van a ayudar' : 'Vecinos interesados'));
              final vacio = esMio
                  ? 'Todavía nadie respondió. Compártelo por WhatsApp para que más vecinos lo vean.'
                  : (p.esColecta
                      ? 'Sé el primero en aportar.'
                      : (p.esPedido ? 'Todavía nadie respondió. ¿Puedes darle una mano?' : 'Todavía nadie lo pidió.'));
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (!esMio)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: SizedBox(
                      height: 60,
                      child: yaRespondi
                          ? OutlinedButton.icon(
                              onPressed: _ocupado ? null : () => _yoAyudo(st, true),
                              icon: const Icon(Icons.undo),
                              label: Text(p.esColecta
                                  ? 'Ya no voy a aportar'
                                  : (p.esPedido ? 'Ya no puedo ayudar' : 'Ya no me interesa')),
                            )
                          : FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: p.esColecta ? const Color(0xFF6A1B9A) : const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _ocupado ? null : () => _yoAyudo(st, false),
                              icon: Icon(p.esColecta ? Icons.diversity_1 : (p.esPedido ? Icons.volunteer_activism : Icons.pan_tool)),
                              label: Text(p.textoResponder, style: const TextStyle(fontSize: 20)),
                            ),
                    ),
                  ),
                if (yaRespondi)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF2E7D32)),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text('Ya respondiste. Ahora ponte de acuerdo por llamada o WhatsApp.',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
                      ),
                    ]),
                  ),
                TituloSeccion('$tituloLista (${lista.length})'),
                if (lista.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(vacio, style: const TextStyle(fontSize: 16)),
                  )
                else
                  for (final a in lista)
                    ListTile(
                      leading: MedallaNivel(Nivel.de(a.ayudasConfirmadas)),
                      title: Text(a.vecinoId == st.uid ? 'Tú' : (a.vecinoNombre ?? 'Vecino')),
                      subtitle: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text('Respondió ${haceCuanto(a.creado)}'),
                        InsigniaNivel(a.ayudasConfirmadas),
                      ]),
                    ),
              ]);
            },
          ),

        if (tel != null && tel.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => llamar(tel),
                  icon: const Icon(Icons.call),
                  label: const Text('Llamar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => abrirWhatsapp(tel, 'Hola ${p.autorVisible}, te escribo por Conecta Vecino: "${p.titulo}".'),
                  icon: const Icon(Icons.chat),
                  label: const Text('WhatsApp'),
                ),
              ),
            ]),
          ),
        ],
        if (!esMio)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextButton.icon(
                onPressed: () => mostrarConsejos(context),
                icon: const Icon(Icons.shield_outlined),
                label: const Text('Consejos para ayudar con seguridad'),
              ),
            ),
          ),
        const Divider(),
        _Dato(Icons.description, 'Detalle', p.descripcion),
        _Dato(Icons.groups, 'Personas', p.personas?.toString()),
        _Dato(Icons.place, 'Ubicación aproximada (±200 m)',
            '${[?p.sector, if (dist != null) formatoDistancia(dist)].join(' · ')}\n'
            'Por seguridad, la dirección exacta se coordina por teléfono.'),
        _Dato(Icons.schedule, 'Publicado', haceCuanto(p.creado)),
        _Dato(p.verificada ? Icons.verified : Icons.flag, 'Estado',
            '${p.estadoTexto}${p.verificada ? ' · Confirmado por una organización o la junta vecinal' : (p.esEmergencia ? ' · Lo publicó un vecino, aún no está confirmado' : '')}'),
        if (p.origen == 'qr')
          const _Dato(Icons.qr_code_2, 'Cómo llegó', 'Un vecino trajo este pedido por código QR porque no tenía internet.'),
        if (p.pendiente)
          const _Dato(Icons.schedule_send, 'Aún no enviado', 'Se publicará apenas haya internet.'),

        if (!p.pendiente && (esOrg || esMio)) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (esOrg && p.esEmergencia && !p.verificada)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FilledButton.tonalIcon(
                    onPressed: _ocupado ? null : () => _verificar(st, true),
                    icon: const Icon(Icons.verified),
                    label: const Text('Verificar (lo confirmamos)'),
                  ),
                ),
              if (esOrg && p.esEmergencia && p.estado == 'abierta')
                FilledButton.icon(
                  onPressed: _ocupado ? null : () => _cambiar(st, 'en_curso', atender: true),
                  icon: const Icon(Icons.health_and_safety),
                  label: const Text('Nuestra organización lo atiende'),
                ),
              if (esOrg && p.esEmergencia && p.estado != 'no_verificado' && p.estado != 'resuelta')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    onPressed: _ocupado ? null : () => _verificar(st, false),
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Marcar como no verificado'),
                  ),
                ),
              if (esMio && p.esColecta && p.estado != 'resuelta') ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _ocupado ? null : () => _actualizarAvance(st),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Anotar donaciones recibidas'),
                ),
              ],
              if (p.estado != 'resuelta') ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
                  onPressed: _ocupado ? null : () => _cerrar(st),
                  icon: const Icon(Icons.check_circle),
                  label: Text(!esMio
                      ? 'Marcar como atendido'
                      : (p.esColecta ? 'Cerrar colecta' : (p.esPedido ? '¡Ya me ayudaron!' : 'Ya lo entregué'))),
                ),
              ],
            ]),
          ),
        ],
        if (!p.pendiente && (esMio || st.esModerador))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFE53935)),
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

