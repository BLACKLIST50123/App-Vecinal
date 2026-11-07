import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config.dart';
import '../../models.dart';
import '../../screens/auth_screen.dart';
import '../../screens/detalles.dart';
import '../../state/app_state.dart';
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
    final dist = p.punto == null ? null : distanciaKm(st.referencia, p.punto!);
    final primario = Theme.of(context).colorScheme.primary;
    final esMio = p.autorId != null && p.autorId == st.uid;

    return SizedBox(
      width: widget.ancho,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        shape: p.esUrgente
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE53935), width: 2))
            : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicacionDetalle(publicacion: p))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
                  child: Icon(cat.icono, size: 20, color: primario),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(cat.nombre,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: primario, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                if (p.esUrgente)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(6)),
                    child: const Text('URGENTE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
              ]),
              const SizedBox(height: 10),
              Text(p.titulo,
                  maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.25)),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.place_outlined, size: 16, color: Paleta.gris),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(dist == null ? (p.sector ?? '') : formatoDistancia(dist),
                      style: const TextStyle(color: Paleta.gris, fontSize: 13)),
                ),
              ]),
              Row(children: [
                const Icon(Icons.schedule, size: 16, color: Paleta.gris),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('${fechaHora(p.creado)} · ${haceCuanto(p.creado)}',
                      style: const TextStyle(color: Paleta.gris, fontSize: 13)),
                ),
              ]),
              Row(children: [
                const Icon(Icons.person_outline, size: 16, color: Paleta.gris),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(p.autorVisible, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Paleta.gris, fontSize: 13)),
                ),
              ]),
              if (p.ayudantes > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('💛 ${p.ayudantes} ${p.ayudantes == 1 ? 'vecino ya apoya' : 'vecinos ya apoyan'}',
                      style: TextStyle(color: primario, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              const Spacer(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: esMio
                    ? const OutlinedButton(onPressed: null, child: Text('Es tu petición'))
                    : _apoyo
                        ? FilledButton.tonalIcon(
                            onPressed: _ocupado ? null : () => _alternar(st),
                            icon: const Icon(Icons.check),
                            label: const Text('Te comprometiste'),
                          )
                        : FilledButton.icon(
                            onPressed: _ocupado ? null : () => _alternar(st),
                            icon: const Icon(Icons.volunteer_activism_outlined),
                            label: const Text('Yo apoyo'),
                          ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
