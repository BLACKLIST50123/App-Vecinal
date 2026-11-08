import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../features/inicio/que_necesitas.dart';
import '../features/inicio/recomendados.dart';
import '../features/junta/junta.dart';
import '../features/inicio/pulso.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/tema.dart';
import '../ui/widgets.dart';
import '../util.dart';
import 'confianza.dart';
import 'detalles.dart';
import '../features/inicio/mapa_inicio.dart';

typedef IrA = void Function(int tab, {String? grupo, String? consulta});

// ============================================================== día a día

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key, required this.irA});
  final IrA irA;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();

    // Estructura (de lo más útil a lo más general):
    //   1) ¿Qué necesitas hoy? (con chips de acceso rápido integrados)
    //   2) Lo más recomendado para ti  3) Buenas noticias del barrio
    //   4) Mapa del barrio con filtros  5) Invitar vecinos
    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          // Invitación de la junta para ser brigadista (si la hay).
          const TarjetaNombramiento(),
          // El brigadista ve primero las alertas SOS de su zona.
          if (st.esBrigadista) const PanelBrigadista(),
          QueNecesitas(irA: irA),
          LoMasRecomendado(verTodos: () => irA(1)),
          const SizedBox(height: 18),
          const PulsoBarrio(),
          const MapaYCercanos(),
          const _InvitarVecinos(),
        ],
      ),
    );
  }
}

/// Invitar vecinos: tarjeta mejorada con mensaje claro e impacto visual.
class _InvitarVecinos extends StatelessWidget {
  const _InvitarVecinos();

  @override
  Widget build(BuildContext context) {
    final online = context.select<AppState, bool>((s) => s.online);
    final verde = Paleta.whatsapp;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      decoration: BoxDecoration(
        color: verde.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: verde.withValues(alpha: 0.30)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Cabecera con gradiente suave
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: verde.withValues(alpha: 0.12),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: verde, shape: BoxShape.circle),
              child: const Icon(Icons.group_add_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Invita a tus vecinos',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Paleta.tinta,
                    )),
                const SizedBox(height: 2),
                Text('Más vecinos = más ayuda para todos.',
                    style: TextStyle(fontSize: 13, color: Paleta.gris)),
              ]),
            ),
          ]),
        ),
        // Beneficio visual: 3 puntos rápidos
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Column(children: [
            for (final item in [
              (Icons.flash_on_rounded, 'Ayuda llega más rápido a tu cuadra'),
              (Icons.verified_user_rounded, 'El barrio se vuelve más seguro'),
              (Icons.storefront_rounded, 'Más servicios y ofertas cerca'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(item.$1, size: 18, color: verde),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item.$2,
                        style: TextStyle(fontSize: 13.5, color: Paleta.tinta, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: verde,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Paleta.lineaFuerte,
              disabledForegroundColor: Paleta.gris,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: online ? () => compartirWhatsapp(textoInvitarVecino) : null,
            icon: const Icon(Icons.send_rounded),
            label: Text(
              online ? 'Enviar invitación por WhatsApp' : 'Necesitas señal para invitar',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ]),
    );
  }
}

// ============================================================== roles

/// Brigadista / líder comunitario: punto focal que recibe las alertas SOS.
class PanelBrigadista extends StatelessWidget {
  const PanelBrigadista({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    // Card (un Material) para que los ListTile de adentro pinten su toque.
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Paleta.rojo.withValues(alpha: 0.35), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Paleta.rojoSuave,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  Icons.health_and_safety,
                  color: Paleta.rojo,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Eres punto focal de tu brigada',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Paleta.rojoOscuro,
                        ),
                      ),
                      Text(
                        st.modoEmergencia
                            ? 'Modo crítico activo: coordina la ayuda y el reparto de recursos.'
                            : 'Aquí llegan las alertas SOS de tus vecinos.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Paleta.tinta,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Cargador<List<Publicacion>>(
            // Una sola fuente de alertas: los SOS del botón de pánico (origen 'sos',
            // vigentes y sin atender), haya o no emergencia activa.
            cargar: (st) => st.repo.alertasSos(),
            builder: (c, todas) {
              // Primero los SOS que la junta le asignó a este brigadista.
              final uid = context.read<AppState>().uid;
              bool mio(Publicacion p) => uid != null && p.atendidoPor == uid;
              final alertas = [...todas]..sort((a, b) => (mio(b) ? 1 : 0) - (mio(a) ? 1 : 0));
              if (alertas.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'Sin alertas SOS abiertas. Todo tranquilo por ahora.',
                    style: TextStyle(color: Paleta.gris),
                  ),
                );
              }
              return Column(
                children: [
                  for (final p in alertas.take(4))
                    ListTile(
                      leading: Icon(
                        buscarCategoria(p.categoria, emergencia: true).icono,
                        color: Paleta.rojo,
                      ),
                      title: Text(
                        p.titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (mio(p)) 'ASIGNADO A TI',
                          p.autorNombre ?? 'Vecino',
                          if (p.sector != null) p.sector!,
                          haceCuanto(p.creado),
                        ].join(' · '),
                        style: mio(p) ? TextStyle(color: Paleta.azulInfo, fontWeight: FontWeight.w700) : null,
                      ),
                      tileColor: mio(p) ? Paleta.azulInfo.withValues(alpha: 0.08) : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        c,
                        MaterialPageRoute(
                          builder: (_) => PublicacionDetalle(publicacion: p),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // La gestión de SOS (derivar, asignar, estados) es solo de la junta.
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Tarjeta de acceso rápido a "Mis aportes" si el usuario ofrece servicios.
class TarjetaMisAportes extends StatelessWidget {
  const TarjetaMisAportes({super.key, required this.irA});
  final IrA irA;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Paleta.acentoSuave,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Paleta.acentoOscuro,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mis aportes en el barrio',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Cargador<(List<Servicio>, List<PedidoServicio>)>(
                  cargar: (st) async => (
                    await st.repo.misServicios(),
                    await st.repo.pedidosRecibidos(),
                  ),
                  builder: (c, datos) {
                    final (servs, pedidos) = datos;
                    final pendientes = pedidos
                        .where((p) => p.esPendiente)
                        .length;
                    return Text(
                      pendientes > 0
                          ? '$pendientes ${pendientes == 1 ? 'pedido pendiente' : 'pedidos pendientes'} · ${servs.length} servicios'
                          : '${servs.length} ${servs.length == 1 ? 'publicación activa' : 'publicaciones activas'}',
                      style: TextStyle(
                        color: pendientes > 0
                            ? Paleta.rosa
                            : Paleta.gris,
                        fontWeight: pendientes > 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () => irA(3),
            child: const Text('Administrar'),
          ),
        ],
      ),
    );
  }
}
