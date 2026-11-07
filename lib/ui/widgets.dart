import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models.dart';
import '../screens/auth_screen.dart';
import '../screens/detalles.dart';
import '../screens/qr_screens.dart';
import '../services/voz.dart';
import '../state/app_state.dart';
import '../util.dart';
import 'diseno.dart';
import 'tema.dart';

// ------------------------------------------------------------ acciones

Future<void> llamar(String telefono) async {
  try {
    await launchUrl(Uri(scheme: 'tel', path: soloDigitos(telefono)));
  } catch (_) {
    avisar('No se pudo abrir el teléfono. Marca: $telefono');
  }
}

Future<void> abrirWhatsapp(String telefono, String mensaje) async {
  var d = soloDigitos(telefono);
  if (d.length == 9) d = '51$d';
  try {
    await launchUrl(
      Uri.parse('https://wa.me/$d?text=${Uri.encodeComponent(mensaje)}'),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    avisar('No se pudo abrir WhatsApp');
  }
}

// ------------------------------------------------------- accesibilidad

/// Botón "Escuchar": lee el contenido en voz alta.
class BotonEscuchar extends StatelessWidget {
  const BotonEscuchar(this.texto, {super.key, this.compacto = false});
  final String texto;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    if (!st.voz) return const SizedBox.shrink();
    if (compacto) {
      return IconButton(
        tooltip: 'Escuchar en voz alta',
        icon: const Icon(Icons.volume_up),
        onPressed: () => Voz.hablar(texto),
      );
    }
    return TextButton.icon(
      onPressed: () => Voz.hablar(texto),
      icon: const Icon(Icons.volume_up),
      label: const Text('Escuchar'),
    );
  }
}

// ------------------------------------------------------------- avisos

class BannerConexion extends StatelessWidget {
  const BannerConexion({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    if (st.online && st.pendientes == 0) return const SizedBox.shrink();
    final offline = !st.online;
    final texto = offline
        ? 'Sin internet. Ves la última información guardada.'
            '${st.pendientes > 0 ? ' ${st.pendientes} por enviar.' : ''}'
        : '${st.pendientes} publicación(es) esperando envío. Toca para ver.';
    return Semantics(
      liveRegion: true,
      child: Material(
        color: offline ? const Color(0xFFFFE082) : const Color(0xFFBBDEFB),
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendientesScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Icon(offline ? Icons.cloud_off : Icons.cloud_upload, color: Colors.black87),
              const SizedBox(width: 12),
              Expanded(child: Text(texto, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
              const Icon(Icons.chevron_right, color: Colors.black87),
            ]),
          ),
        ),
      ),
    );
  }
}

class BannerEmergencia extends StatelessWidget {
  const BannerEmergencia({super.key, this.grande = false});
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    if (!st.modoEmergencia) return const SizedBox.shrink();
    final e = st.emergencia;
    final titulo = e.titulo ?? 'Modo emergencia activo';
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: const Color(0xFFB71C1C),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: grande ? 16 : 8),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('EMERGENCIA: $titulo',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              if (grande && e.mensaje != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(e.mensaje!, style: const TextStyle(color: Colors.white)),
                ),
            ]),
          ),
          if (st.voz)
            IconButton(
              tooltip: 'Escuchar aviso',
              color: Colors.white,
              icon: const Icon(Icons.volume_up),
              onPressed: () => Voz.hablar('Emergencia. $titulo. ${e.mensaje ?? ''}'),
            ),
        ]),
      ),
    );
  }
}

// -------------------------------------------------------------- piezas

class EstadoVacio extends StatelessWidget {
  const EstadoVacio({super.key, required this.icono, required this.texto, this.accion});
  final IconData icono;
  final String texto;
  final (String, VoidCallback)? accion;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(texto, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          if (accion != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: accion!.$2, child: Text(accion!.$1)),
          ],
        ]),
      );
}

class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key, this.accion});
  final String texto;
  final (String, VoidCallback)? accion;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
        child: Row(children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(texto, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ),
          if (accion != null) TextButton(onPressed: accion!.$2, child: Text(accion!.$1)),
        ]),
      );
}

/// Insignia de confianza según el rol del autor.
class InsigniaRol extends StatelessWidget {
  const InsigniaRol(this.rol, {super.key});
  final String? rol;

  @override
  Widget build(BuildContext context) {
    final (String, IconData, Color)? info = switch (rol) {
      'organizacion' => ('Organización verificada', Icons.verified, const Color(0xFF1565C0)),
      'moderador' => ('Junta vecinal', Icons.shield, const Color(0xFF6A1B9A)),
      _ => null,
    };
    if (info == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(info.$2, size: 16, color: info.$3),
        const SizedBox(width: 2),
        Flexible(child: Text(info.$1, style: TextStyle(color: info.$3, fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class EtiquetaPendiente extends StatelessWidget {
  const EtiquetaPendiente({super.key});
  @override
  Widget build(BuildContext context) => const Chip(
        avatar: Icon(Icons.schedule_send, size: 18),
        label: Text('Por enviar'),
        visualDensity: VisualDensity.compact,
      );
}

/// Carga datos cuando cambia `AppState.version` o las `claves`.
class Cargador<T> extends StatefulWidget {
  const Cargador({super.key, required this.cargar, required this.builder, this.claves = const []});
  final Future<T> Function(AppState st) cargar;
  final Widget Function(BuildContext context, T datos) builder;
  final List<Object?> claves;

  @override
  State<Cargador<T>> createState() => _CargadorState<T>();
}

class _CargadorState<T> extends State<Cargador<T>> {
  Future<T>? _futuro;
  int _version = -1;
  List<Object?> _claves = const [];

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    if (_futuro == null || st.version != _version || !listEquals(_claves, widget.claves)) {
      _version = st.version;
      _claves = List.of(widget.claves);
      _futuro = widget.cargar(st);
    }
    return FutureBuilder<T>(
      future: _futuro,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(
            child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(semanticsLabel: 'Cargando')),
          );
        }
        if (s.hasError) {
          return EstadoVacio(
            icono: Icons.error_outline,
            texto: 'No pudimos cargar la información.\nRevisa tu conexión e intenta otra vez.',
            accion: ('Reintentar', st.refrescar),
          );
        }
        return widget.builder(c, s.data as T);
      },
    );
  }
}

// ------------------------------------------------------------ tarjetas

class TarjetaServicio extends StatelessWidget {
  const TarjetaServicio(this.s, {super.key});
  final Servicio s;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final cat = buscarCategoria(s.categoria, emergencia: s.esEmergencia);
    final dist = s.punto == null ? null : distanciaKm(st.referencia, s.punto!);
    final esquema = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServicioDetalle(servicio: s))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: esquema.primaryContainer,
                child: Icon(cat.icono, color: esquema.onPrimaryContainer, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.titulo, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                    Text(s.autorNombre ?? 'Vecino'),
                    InsigniaRol(s.autorRol),
                  ]),
                  Text(
                    [cat.nombre, ?s.sector, if (dist != null) formatoDistancia(dist)].join(' · '),
                    style: TextStyle(color: esquema.onSurfaceVariant),
                  ),
                ]),
              ),
              BotonEscuchar(s.textoParaVoz, compacto: true),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              if (s.pendiente)
                const EtiquetaPendiente()
              else
                Semantics(
                  label: '${s.vistosBuenos} vecinos le dieron Visto Bueno',
                  excludeSemantics: true,
                  child: Row(children: [
                    Icon(Icons.thumb_up, color: s.vistosBuenos > 0 ? const Color(0xFF2E7D32) : esquema.outline),
                    const SizedBox(width: 6),
                    Text(
                      s.vistosBuenos == 0
                          ? 'Aún sin Visto Bueno'
                          : '${s.vistosBuenos} Visto${s.vistosBuenos == 1 ? '' : 's'} Bueno${s.vistosBuenos == 1 ? '' : 's'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
              const Spacer(),
              if (s.telefono != null && s.telefono!.isNotEmpty)
                FilledButton.tonalIcon(
                  onPressed: () => llamar(s.telefono!),
                  icon: const Icon(Icons.call),
                  label: const Text('Llamar'),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Tarjeta de solicitud (diseño Figma): iniciales, título, detalle y la
/// acción principal en la misma tarjeta ("Quiero ayudar" / "Me he ofrecido").
class TarjetaPublicacion extends StatefulWidget {
  const TarjetaPublicacion(this.p, {super.key});
  final Publicacion p;

  @override
  State<TarjetaPublicacion> createState() => _TarjetaPublicacionState();
}

class _TarjetaPublicacionState extends State<TarjetaPublicacion> {
  bool _respondi = false;
  bool _ocupado = false;

  Publicacion get p => widget.p;

  Future<void> _responder(AppState st) async {
    if (!st.logueado) {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => const AuthScreen(mensaje: 'Para responder necesitas una cuenta de vecino. Es gratis y toma 1 minuto.'),
      ));
      return;
    }
    setState(() => _ocupado = true);
    try {
      if (_respondi) {
        await st.repo.retirarAyuda(p.id);
        setState(() => _respondi = false);
        avisar('Listo, ya no apareces en la lista.');
      } else {
        await st.repo.ofrecerAyuda(p.id);
        setState(() => _respondi = true);
        mensajero.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('¡Gracias! Ahora ponte de acuerdo con ${p.autorVisible}.'),
            action: SnackBarAction(
              label: 'Ver',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicacionDetalle(publicacion: p))),
            ),
          ));
      }
      st.refrescar();
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        setState(() => _respondi = true);
      } else {
        avisar(traducirError(e));
      }
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
    final dist = p.punto == null ? null : distanciaKm(st.referencia, p.punto!);
    final esquema = Theme.of(context).colorScheme;
    final critica = p.esEmergencia && p.prioridad == 'critica';
    final esMio = p.autorId != null && p.autorId == st.uid;
    final puedeResponder = !esMio && !p.pendiente && p.estado != 'resuelta';
    final (fg, bg) = p.esColecta
        ? (const Color(0xFF6A1B9A), const Color(0xFFF3E5F5))
        : critica
            ? (const Color(0xFFB71C1C), const Color(0xFFFDE7E7))
            : p.esPedido
                ? (esquema.primary, esquema.primaryContainer)
                : (const Color(0xFF376A89), const Color(0xFFE3EFF5));
    final textoRespondido = p.esColecta ? 'Ya aportaste' : (p.esPedido ? 'Me he ofrecido' : 'Te interesa');

    return Card(
      shape: critica
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFB71C1C), width: 2))
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicacionDetalle(publicacion: p))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: bg,
              child: p.esColecta
                  ? Icon(Icons.diversity_1, color: fg)
                  : Text(iniciales(p.autorVisible), style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (p.esColecta) const _Etiqueta('COLECTA', Color(0xFF6A1B9A)),
                  if (!p.esPedido) const _Etiqueta('OFRECE', Color(0xFF376A89)),
                  if (critica) const _Etiqueta('MUY URGENTE', Color(0xFFB71C1C)),
                  if (p.esEmergencia && p.prioridad == 'alta') const _Etiqueta('URGENTE', Color(0xFFC62828)),
                  if (p.verificada) const _Etiqueta('✓ VERIFICADO', Color(0xFF00695C)),
                  if (p.estado == 'no_verificado') const _Etiqueta('SIN CONFIRMAR', Color(0xFF616161)),
                  if (p.origen == 'qr') const _Etiqueta('LLEGÓ POR QR', Color(0xFF6A1B9A)),
                  if (p.pendiente) const _Etiqueta('POR ENVIAR', Color(0xFF616161)),
                ]),
                const SizedBox(height: 2),
                Text(p.titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25)),
                const SizedBox(height: 3),
                Text(
                  [
                    cat.nombre,
                    ?p.sector,
                    if (dist != null) formatoDistancia(dist),
                    haceCuanto(p.creado),
                  ].join(' · '),
                  style: const TextStyle(color: Paleta.gris, fontSize: 13),
                ),
                if (p.esColecta && p.meta != null)
                  Padding(padding: const EdgeInsets.only(top: 8), child: BarraColecta(p)),
                if (!p.esColecta && p.ayudantes > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      p.esPedido
                          ? '💛 ${p.ayudantes} ${p.ayudantes == 1 ? 'vecino va' : 'vecinos van'} a ayudar'
                          : '🙋 ${p.ayudantes} ${p.ayudantes == 1 ? 'interesado' : 'interesados'}',
                      style: TextStyle(color: esquema.primary, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(children: [
                  if (puedeResponder)
                    _respondi
                        ? FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            onPressed: _ocupado ? null : () => _responder(st),
                            icon: const Icon(Icons.check, size: 18),
                            label: Text(textoRespondido),
                          )
                        : FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 42),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              backgroundColor: p.esColecta ? const Color(0xFF6A1B9A) : null,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            onPressed: _ocupado ? null : () => _responder(st),
                            child: Text(p.esColecta ? 'Yo aporto' : (p.esPedido ? 'Quiero ayudar' : 'Me interesa')),
                          )
                  else if (p.estado == 'resuelta')
                    Text(p.estadoTexto, style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w700)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Insignia de reconocimiento vecinal ("🤝 Vecino solidario").
class InsigniaNivel extends StatelessWidget {
  const InsigniaNivel(this.ayudas, {super.key, this.mostrarSiCero = false});
  final int ayudas;
  final bool mostrarSiCero;

  @override
  Widget build(BuildContext context) {
    if (ayudas == 0 && !mostrarSiCero) return const SizedBox.shrink();
    final n = Nivel.de(ayudas);
    return Semantics(
      label: 'Reconocimiento: ${n.nombre}, $ayudas ayudas confirmadas',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFB300))),
        child: Text('${n.emoji} ${n.nombre}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
    );
  }
}

/// Avance de una colecta: "18 de 30 donaciones · faltan 12".
class BarraColecta extends StatelessWidget {
  const BarraColecta(this.p, {super.key, this.grande = false});
  final Publicacion p;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final meta = p.meta ?? 0;
    final faltan = (meta - p.aportes).clamp(0, meta);
    const color = Color(0xFF6A1B9A);
    final texto = faltan == 0
        ? '¡Meta cumplida! ${p.aportes} de $meta'
        : '${p.aportes} de $meta donaciones · faltan $faltan';
    return Semantics(
      label: texto,
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: p.progreso,
            minHeight: grande ? 16 : 10,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
        ),
        const SizedBox(height: 4),
        Text(texto, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: grande ? 18 : 14)),
      ]),
    );
  }
}

/// Tarjeta compacta para el carrusel de "Colectas del barrio".
class TarjetaColecta extends StatelessWidget {
  const TarjetaColecta(this.p, {super.key});
  final Publicacion p;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 270,
        child: Card(
          color: const Color(0xFFF3E5F5),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicacionDetalle(publicacion: p))),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.diversity_1, color: Color(0xFF6A1B9A)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(p.autorVisible,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                  ),
                  if (p.autorRol == 'organizacion') const Icon(Icons.verified, size: 18, color: Color(0xFF1565C0)),
                ]),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(p.titulo,
                      maxLines: 3, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                ),
                BarraColecta(p),
                const SizedBox(height: 6),
                const Text('Toca para aportar →', style: TextStyle(color: Color(0xFF6A1B9A), fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      );
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto, this.color);
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
        child: Text(texto, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      );
}

/// Selector horizontal de categorías con chips grandes.
class SelectorCategorias extends StatelessWidget {
  const SelectorCategorias({super.key, required this.categorias, required this.seleccion, required this.onCambio, this.conTodas = true});
  final List<Categoria> categorias;
  final String? seleccion;
  final ValueChanged<String?> onCambio;
  final bool conTodas;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            if (conTodas)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Todas'),
                  selected: seleccion == null,
                  onSelected: (_) => onCambio(null),
                ),
              ),
            for (final c in categorias)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(c.icono, size: 20),
                  label: Text(c.nombre),
                  selected: seleccion == c.id,
                  onSelected: (_) => onCambio(c.id),
                ),
              ),
          ],
        ),
      );
}
