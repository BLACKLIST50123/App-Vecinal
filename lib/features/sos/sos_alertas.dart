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

/// Franja "Alerta SOS activa": muestra solo la alerta más urgente y reciente
/// (el repo ya las ordena así) y un botón para ver todas. Si no hay
/// alertas, no ocupa espacio.
class FranjaAlertasSos extends StatelessWidget {
  const FranjaAlertasSos({super.key});

  @override
  Widget build(BuildContext context) => Cargador<List<Publicacion>>(
        cargar: (st) => st.repo.alertasSos(),
        builder: (context, alertas) {
          if (alertas.isEmpty) return const SizedBox.shrink();
          final p = alertas.first;
          final st = context.watch<AppState>();
          final dist = p.punto == null ? null : distanciaKm(st.referencia, p.punto!);
          final detalle = [
            buscarCategoria(p.categoria, emergencia: true).nombre,
            ?p.sector,
            if (dist != null) formatoDistancia(dist),
          ].join(' · ');

          return Semantics(
            liveRegion: true,
            container: true,
            label: '${alertas.length} ${alertas.length == 1 ? 'alerta SOS activa' : 'alertas SOS activas'}',
            child: Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PublicacionDetalle(publicacion: p))),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: Paleta.rojo, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text('Alerta SOS activa',
                                style: TextStyle(color: Paleta.rojo, fontSize: 13, fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Text(haceCuanto(p.creado), style: TextStyle(color: Paleta.gris, fontSize: 12)),
                          ]),
                          const SizedBox(height: 6),
                          Text(p.titulo,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.25)),
                          if (detalle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(detalle, style: TextStyle(color: Paleta.gris, fontSize: 13)),
                          ],
                        ]),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, color: Paleta.gris),
                    ]),
                  ),
                ),
                if (alertas.length > 1) ...[
                  const Divider(height: 1),
                  TextButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertasSosScreen())),
                    icon: const Icon(Icons.list_alt, size: 20),
                    label: Text('Mostrar todas (${alertas.length})'),
                  ),
                ],
              ]),
            ),
          );
        },
      );
}

/// Todas las alertas SOS activas, con filtro por prioridad y orden por fecha.
class AlertasSosScreen extends StatefulWidget {
  const AlertasSosScreen({super.key});

  @override
  State<AlertasSosScreen> createState() => _AlertasSosScreenState();
}

class _AlertasSosScreenState extends State<AlertasSosScreen> {
  String _prioridad = 'todas';
  bool _antiguas = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Alertas SOS activas')),
        body: Cargador<List<Publicacion>>(
          cargar: (st) => st.repo.alertasSos(),
          builder: (context, todas) {
            if (todas.isEmpty) {
              return const EstadoVacio(icono: Icons.check_circle, texto: 'No hay alertas SOS activas. ¡Todo tranquilo!');
            }
            int cuantas(String pr) => todas.where((p) => p.prioridad == pr).length;
            final lista = todas.where((p) => _prioridad == 'todas' || p.prioridad == _prioridad).toList()
              ..sort((a, b) => _antiguas ? a.creado.compareTo(b.creado) : b.creado.compareTo(a.creado));
            final primario = Theme.of(context).colorScheme.primary;

            return ListView(padding: const EdgeInsets.only(top: 4, bottom: 32), children: [
              FilaPildoras(
                opciones: [
                  ('todas', 'Todas (${todas.length})'),
                  ('critica', 'Muy urgentes (${cuantas('critica')})'),
                  ('alta', 'Urgentes (${cuantas('alta')})'),
                ],
                seleccion: _prioridad,
                onCambio: (v) => setState(() => _prioridad = v),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
                child: Row(children: [
                  Expanded(
                    child: Text('${lista.length} ${lista.length == 1 ? 'alerta' : 'alertas'}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17)),
                  ),
                  PopupMenuButton<bool>(
                    tooltip: 'Ordenar',
                    initialValue: _antiguas,
                    onSelected: (v) => setState(() => _antiguas = v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: false, child: Text('Más recientes')),
                      PopupMenuItem(value: true, child: Text('Más antiguas')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.swap_vert, color: primario),
                        const SizedBox(width: 4),
                        Text(_antiguas ? 'Más antiguas' : 'Más recientes',
                            style: TextStyle(color: primario, fontWeight: FontWeight.w700, fontSize: 14)),
                      ]),
                    ),
                  ),
                ]),
              ),
              if (lista.isEmpty)
                const EstadoVacio(icono: Icons.filter_alt_off, texto: 'No hay alertas con ese filtro.')
              else
                for (final p in lista) TarjetaPublicacion(p),
            ]);
          },
        ),
      );
}
