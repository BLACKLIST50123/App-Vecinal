import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config.dart';
import '../../models.dart';
import '../../screens/auth_screen.dart';
import '../../screens/detalles.dart';
import '../../state/app_state.dart';
import '../../ui/diseno.dart';
import '../../ui/tema.dart';
import '../../util.dart';

/// Tarjeta de una petición para el carrusel "Apoyar".
/// Orden de lectura: categoría y urgencia → qué necesita → dónde y cuándo →
/// quién → una sola acción: "Yo apoyo".
class TarjetaApoyo extends StatefulWidget {
  const TarjetaApoyo(this.p, {super.key, this.ancho = 260});
  final Publicacion p;
  final double ancho;

  @override
  State<TarjetaApoyo> createState() => _TarjetaApoyoState();
}

class _TarjetaApoyoState extends State<TarjetaApoyo> {
  bool _apoyo = false;
  bool _ocupado = false;

  Publicacion get p => widget.p;

  Future<void> _alternar(AppState st) async {
    if (!st.logueado) {
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => const AuthScreen(mensaje: 'Para apoyar a un vecino necesitas una cuenta. Es gratis y toma 1 minuto.'),
      ));
      return;
    }
    setState(() => _ocupado = true);
    try {
      if (_apoyo) {
        await st.repo.retirarAyuda(p.id);
        setState(() => _apoyo = false);
        avisar('Listo, ya no apareces como apoyo.');
      } else {
        await st.repo.ofrecerAyuda(p.id);
        setState(() => _apoyo = true);
        mensajero.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('¡Gracias! Ahora ponte de acuerdo con ${p.autorVisible}.'),
            action: SnackBarAction(
              label: 'Contactar',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicacionDetalle(publicacion: p))),
            ),
          ));
      }
      st.refrescar();
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        setState(() => _apoyo = true);
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
    final cat = buscarCategoria(p.categoria);
    final colores = coloresPeticion(categoriaPeticion(p.categoria));
    final dist = p.punto == null ? null : distanciaKm(st.referencia, p.punto!);
    final esMio = p.autorId != null && p.autorId == st.uid;
    final boton = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

    return Container(
      width: widget.ancho,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Paleta.superficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Paleta.linea),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicacionDetalle(publicacion: p))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(height: 5, color: p.esUrgente ? Paleta.rojo : colores.$1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
                        decoration: BoxDecoration(color: colores.$2, borderRadius: BorderRadius.circular(999)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(cat.icono, size: 15, color: colores.$1),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(cat.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: colores.$1, fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ),
                    ),
                    if (p.esUrgente) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Paleta.rojoSuave, borderRadius: BorderRadius.circular(999)),
                        child: Text('URGENTE',
                            style: TextStyle(color: Paleta.rojoTexto, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 10),
                  Text(p.titulo,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.25, color: Paleta.tinta)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.place_rounded, size: 16, color: Paleta.primario),
                    const SizedBox(width: 3),
                    Text(dist == null ? (p.sector ?? 'Cerca') : formatoDistancia(dist),
                        style: TextStyle(color: Paleta.primario, fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(fechaHora(p.creado),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Paleta.gris, fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Paleta.acentoSuave,
                      child: Text(iniciales(p.autorVisible),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Paleta.acentoOscuro)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(p.autorVisible,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Paleta.tinta)),
                    ),
                  ]),
                  if (p.ayudantes > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(children: [
                        Icon(Icons.favorite_rounded, size: 15, color: Paleta.acentoOscuro),
                        const SizedBox(width: 5),
                        Text('${p.ayudantes} ${p.ayudantes == 1 ? 'vecino ya apoya' : 'vecinos ya apoyan'}',
                            style: TextStyle(color: Paleta.acentoOscuro, fontWeight: FontWeight.w700, fontSize: 13)),
                      ]),
                    ),
                  const Spacer(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: esMio
                        ? OutlinedButton(style: OutlinedButton.styleFrom(shape: boton), onPressed: null, child: const Text('Es tu petición'))
                        : _apoyo
                            ? FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(shape: boton),
                                onPressed: _ocupado ? null : () => _alternar(st),
                                icon: const Icon(Icons.check_rounded),
                                label: const Text('Te comprometiste'),
                              )
                            : FilledButton.icon(
                                style: FilledButton.styleFrom(shape: boton),
                                onPressed: _ocupado ? null : () => _alternar(st),
                                icon: const Icon(Icons.volunteer_activism_rounded),
                                label: const Text('Yo apoyo', style: TextStyle(fontWeight: FontWeight.w800)),
                              ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Colores (texto, fondo) de cada categoría de petición, dentro de la paleta.
(Color, Color) coloresPeticion(String? id) => switch (id) {
      'herramientas' => Paleta.naranja,
      'ayuda' => Paleta.azul,
      'movilidad' => Paleta.morado,
      'donacion' => Paleta.verdeCat,
      'habilidad' => (Paleta.ambar, Paleta.ambarSuave),
      null => (Paleta.primario, Paleta.primarioSuave),
      _ => (Paleta.gris, Paleta.grisFondo),
    };
