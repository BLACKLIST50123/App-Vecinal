import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../models.dart';
import '../../screens/detalles.dart';
import '../../state/app_state.dart';
import '../../ui/diseno.dart';
import '../../ui/tema.dart';
import '../../ui/widgets.dart';
import '../../util.dart';

/// Servicio con su distancia (km) a la persona; null si no tiene ubicación.
typedef Recomendado = ({Servicio servicio, double? km});

/// Ordena por lo que más confía el barrio: Vistos Buenos primero y, a igual
/// confianza, lo más cerca. Lo que está lejos pierde un poco.
List<Recomendado> rankingRecomendados(List<Servicio> todos, Punto referencia, {String? categoria, int max = 3}) {
  final lista = [
    for (final s in todos)
      if (s.activo && !s.esEmergencia && (categoria == null || s.categoria == categoria))
        (servicio: s, km: s.punto == null ? null : distanciaKm(referencia, s.punto!)),
  ];
  double puntaje(Recomendado r) => r.servicio.vistosBuenos - ((r.km ?? 5) * 0.5);
  lista.sort((a, b) {
    final p = puntaje(b).compareTo(puntaje(a));
    return p != 0 ? p : (a.km ?? 99).compareTo(b.km ?? 99);
  });
  return lista.take(max).toList();
}

String detalleRecomendado(Recomendado r) => [
      if (r.servicio.vistosBuenos > 0)
        '${r.servicio.vistosBuenos} ${r.servicio.vistosBuenos == 1 ? 'Visto Bueno' : 'Vistos Buenos'}',
      if (r.km != null) 'a ${formatoDistancia(r.km!)}',
      if (r.km == null && r.servicio.sector != null) r.servicio.sector!,
    ].join(' · ');

/// "Lo más recomendado para ti": los 3 servicios o productos con más
/// confianza del barrio, cada uno con "Ir" a su ficha.
class LoMasRecomendado extends StatelessWidget {
  const LoMasRecomendado({super.key, required this.verTodos});
  final VoidCallback verTodos;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TituloDiseno('Lo más recomendado para ti', accion: ('Ver todos', verTodos)),
      Cargador<List<Servicio>>(
        cargar: (st) => st.repo.servicios(emergencia: false),
        builder: (c, todos) {
          final lista = rankingRecomendados(todos, context.read<AppState>().referencia);
          if (lista.isEmpty) {
            return const EstadoVacio(
              icono: Icons.storefront_outlined,
              texto: 'Aún no hay servicios en tu barrio. Sé el primero: publica lo que sabes hacer o vendes.',
            );
          }
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Paleta.superficie,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Paleta.linea),
            ),
            child: Column(children: [
              for (var i = 0; i < lista.length; i++) ...[
                if (i > 0) Divider(height: 1, color: Paleta.linea, indent: 16, endIndent: 16),
                _FilaRecomendado(lista[i], puesto: i + 1),
              ],
            ]),
          );
        },
      ),
    ]);
  }
}

class _FilaRecomendado extends StatelessWidget {
  const _FilaRecomendado(this.r, {required this.puesto});
  final Recomendado r;
  final int puesto;

  void _ir(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => ServicioDetalle(servicio: r.servicio)));

  @override
  Widget build(BuildContext context) {
    final s = r.servicio;
    final cat = buscarCategoria(s.categoria);
    final (fuerte, suave) = colorGrupo(grupoServicio(s.categoria));
    final detalle = detalleRecomendado(r);
    return InkWell(
      onTap: () => _ir(context),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: suave, borderRadius: BorderRadius.circular(15)),
              child: Icon(cat.icono, color: fuerte, size: 26),
            ),
            // El primero lleva medalla: "el más recomendado del barrio".
            if (puesto == 1)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(color: Paleta.superficie, shape: BoxShape.circle),
                  child: Icon(Icons.workspace_premium_rounded, size: 20, color: Paleta.oro),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Paleta.tinta)),
              Text(cat.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Paleta.gris)),
              if (detalle.isNotEmpty)
                Text(detalle,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Paleta.verde)),
            ]),
          ),
          const SizedBox(width: 10),
          // Botón "Ir" prominente con flecha para indicar acción clara.
          Semantics(
            button: true,
            label: 'Ir a ${s.titulo}',
            excludeSemantics: true,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Paleta.acentoOscuro,
                foregroundColor: Colors.white,
                minimumSize: const Size(72, 46),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _ir(context),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Ir', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}
