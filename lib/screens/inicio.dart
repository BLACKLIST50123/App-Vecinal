import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../features/inicio/mapa_inicio.dart';
import '../features/junta/junta.dart';
import '../features/inicio/pulso.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/diseno.dart';
import '../ui/tema.dart';
import '../ui/widgets.dart';
import '../util.dart';
import 'confianza.dart';
import 'detalles.dart';
import 'mapa.dart';
import 'publicar.dart';
import 'qr_screens.dart';

typedef IrA = void Function(int tab, {String? grupo, String? consulta});

// ============================================================== día a día

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key, required this.irA});
  final IrA irA;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();

    // Estructura: 1) bienvenida y pulso del barrio  2) mapa con filtros
    // 3) cerca de ti  4) ¿qué quieres hacer hoy?
    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          // Invitación de la junta para ser brigadista (si la hay).
          const TarjetaNombramiento(),
          // El brigadista ve primero las alertas SOS de su zona.
          if (st.esBrigadista) const PanelBrigadista(),
          const _Bienvenida(),
          const PulsoBarrio(),
          const MapaYCercanos(),
          const TituloDiseno('¿Qué quieres hacer hoy?'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: AccesoCategoria(
                  texto: 'Pedir ayuda',
                  icono: Icons.front_hand_outlined,
                  colores: Paleta.morado,
                  onTap: () => irA(2, grupo: 'pedir'),
                ),
              ),
              Expanded(
                child: AccesoCategoria(
                  texto: 'Ofrecer servicio',
                  icono: Icons.storefront_outlined,
                  colores: Paleta.naranja,
                  onTap: () => abrirFormulario(context, TipoForm.servicio),
                ),
              ),
              Expanded(
                child: AccesoCategoria(
                  texto: 'Ver colectas',
                  icono: Icons.diversity_1_outlined,
                  colores: Paleta.verdeCat,
                  onTap: () => irA(2),
                ),
              ),
            ]),
          ),
          // Al final: invitar a más vecinos.
          const BotonInvitarWhatsapp(),
        ],
      ),
    );
  }
}

/// "Conecta Vecino · ¡La app que nos une!"
class _Bienvenida extends StatelessWidget {
  const _Bienvenida();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
        child: Semantics(
          header: true,
          label: 'Conecta Vecino. ¡La app que nos une!',
          excludeSemantics: true,
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset('assets/images/logo_icono.png', width: 44, height: 44, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Conecta Vecino',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Paleta.tinta, letterSpacing: -0.3)),
                Text('¡La app que nos une!',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Paleta.acentoOscuro)),
              ]),
            ),
          ]),
        ),
      );
}

// ============================================================= emergencia

class EmergenciaScreen extends StatelessWidget {
  const EmergenciaScreen({super.key, required this.irA});
  final ValueChanged<int> irA;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    const rojo = Paleta.rojo;
    const rojoCat = (Paleta.rojo, Paleta.rojoSuave);
    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          if (st.esBrigadista) ...[
            const PanelBrigadista(),
            const SizedBox(height: 12),
          ],
          if (st.emergencia.mensaje != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      st.emergencia.mensaje!,
                      style: const TextStyle(fontSize: 15, color: Paleta.tinta),
                    ),
                  ),
                  BotonEscuchar(
                    'Emergencia. ${st.emergencia.titulo ?? ''}. ${st.emergencia.mensaje}',
                    compacto: true,
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Semantics(
              button: true,
              label: 'Necesito ayuda. Publica un pedido de ayuda urgente. Funciona sin cuenta y sin internet.',
              excludeSemantics: true,
              child: SizedBox(
                height: 96,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: rojo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  onPressed: () =>
                      abrirFormulario(context, TipoForm.necesitoAyuda),
                  icon: const Icon(Icons.sos, size: 44),
                  label: const Text(
                    'NECESITO AYUDA',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Funciona sin cuenta y sin internet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Paleta.gris),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AccesoCategoria(
                    texto: 'Avisar de un vecino',
                    icono: Icons.elderly,
                    colores: rojoCat,
                    onTap: () =>
                        abrirFormulario(context, TipoForm.reportarVulnerable),
                  ),
                ),
                Expanded(
                  child: AccesoCategoria(
                    texto: 'Tengo algo para compartir',
                    icono: Icons.inventory_2_outlined,
                    colores: Paleta.verdeCat,
                    onTap: () =>
                        abrirFormulario(context, TipoForm.ofrezcoRecurso),
                  ),
                ),
                Expanded(
                  child: AccesoCategoria(
                    texto: 'Grupos de apoyo',
                    icono: Icons.health_and_safety_outlined,
                    colores: Paleta.azul,
                    onTap: () => irA(1),
                  ),
                ),
                Expanded(
                  child: AccesoCategoria(
                    texto: 'Mapa de ayuda',
                    icono: Icons.map_outlined,
                    colores: Paleta.morado,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PantallaMapaCompleto(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const AvisoAutoridades(),
          const SizedBox(height: 6),
          ListaAjustes(
            filas: [
              if (st.esOrganizacion || st.esModerador || st.esBrigadista)
                FilaAjuste(
                  icono: Icons.dashboard_outlined,
                  texto: 'Panel de coordinación',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PanelCoordinacionScreen(),
                    ),
                  ),
                ),
              FilaAjuste(
                icono: Icons.qr_code_scanner,
                texto: '¿Sin internet? Lleva mensajes por QR',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EscanearQrScreen()),
                ),
              ),
            ],
          ),
          TituloDiseno(
            'Pedidos de ayuda urgentes',
            accion: ('Ver todos', () => irA(2)),
          ),
          Cargador<List<Publicacion>>(
            cargar: (st) => st.repo.publicaciones(emergencia: true),
            builder: (c, lista) {
              final pedidos = lista.where((p) => p.esPedido).toList()
                ..sort((a, b) {
                  final x = b.pesoPrioridad.compareTo(a.pesoPrioridad);
                  return x != 0 ? x : b.creado.compareTo(a.creado);
                });
              if (pedidos.isEmpty) {
                return const EstadoVacio(
                  icono: Icons.check_circle,
                  texto: 'No hay pedidos abiertos por ahora.',
                );
              }
              return Column(
                children: [
                  for (final p in pedidos.take(5)) TarjetaPublicacion(p),
                ],
              );
            },
          ),
        ],
      ),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Paleta.rojo.withValues(alpha: 0.35),
          width: 1.5,
        ),
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
                const Icon(
                  Icons.health_and_safety,
                  color: Paleta.rojo,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
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
                        style: const TextStyle(
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
            builder: (c, alertas) {
              if (alertas.isEmpty) {
                return const Padding(
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
                          p.autorNombre ?? 'Vecino',
                          if (p.sector != null) p.sector!,
                          haceCuanto(p.creado),
                        ].join(' · '),
                      ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PanelCoordinacionScreen(),
                ),
              ),
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Panel de coordinación'),
            ),
          ),
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
