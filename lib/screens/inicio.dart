import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../features/sos/sos_alertas.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/diseno.dart';
import '../ui/tema.dart';
import '../ui/widgets.dart';
import '../util.dart';
import 'confianza.dart';
import 'publicar.dart';
import 'qr_screens.dart';
import 'roles.dart';
import 'detalles.dart';

typedef IrA = void Function(int tab, {String? grupo, String? consulta});

// ============================================================== día a día

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key, required this.irA});
  final IrA irA;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();

    // Estructura: 1) dónde estoy y qué busco  2) explorar  3) solidaridad
    //             4) lo más cercano  5) quién necesita ayuda.
    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: ListView(padding: const EdgeInsets.only(bottom: 110), children: [
        // Lo más urgente primero: alertas SOS de vecinos (si las hay).
        // El brigadista ya las ve en su panel, así que no se repiten.
        if (!st.esBrigadista) const FranjaAlertasSos(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            PildoraUbicacion(texto: st.sector ?? Zona.nombre, onTap: () => irA(3)),
            const PildoraRol(),
          ]),
        ),
        if (st.esBrigadista) const PanelBrigadista(),
        if (st.esPrestadorRol) const TarjetaPrestador(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: CajaBusqueda(
            pista: '¿Qué necesitas hoy?',
            etiqueta: 'Buscar en tu barrio',
            onSubmitted: (v) => irA(1, consulta: v.trim().isEmpty ? null : v.trim()),
          ),
        ),

        const TituloDiseno('Explora tu barrio', ceja: 'Todo cerca de ti'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(child: AccesoCategoria(texto: 'Servicios', icono: Icons.handyman_outlined, colores: Paleta.naranja, onTap: () => irA(1, grupo: 'servicios'))),
            Expanded(child: AccesoCategoria(texto: 'Productos', icono: Icons.shopping_basket_outlined, colores: Paleta.azul, onTap: () => irA(1, grupo: 'productos'))),
            Expanded(child: AccesoCategoria(texto: 'Clases', icono: Icons.menu_book_outlined, colores: Paleta.verdeCat, onTap: () => irA(1, grupo: 'clases'))),
            Expanded(child: AccesoCategoria(texto: 'Ver más', icono: Icons.more_horiz, colores: Paleta.morado, onTap: () => irA(1))),
          ]),
        ),

        const SizedBox(height: 22),
        BannerDegradado(
          icono: Icons.favorite_border,
          titulo: 'Entre vecinos nos ayudamos',
          subtitulo: 'Pide una mano o responde a una solicitud',
          colores: const [Paleta.primario, Paleta.primarioClaro],
          onTap: () => irA(2),
        ),

        TituloDiseno('Cerca de ti', accion: ('Ver todo', () => irA(1))),
        Cargador<List<Servicio>>(
          cargar: (st) => st.repo.servicios(emergencia: false),
          builder: (c, lista) {
            if (lista.isEmpty) {
              return const EstadoVacio(icono: Icons.storefront, texto: 'Todavía no hay servicios ni productos publicados.');
            }
            final ref = st.referencia;
            // Cerca y bien recomendados: ordena por distancia y desempata por Visto Bueno.
            final orden = [...lista]..sort((a, b) {
                final da = a.punto == null ? 99.0 : distanciaKmRedondeada(ref, a.punto!);
                final db = b.punto == null ? 99.0 : distanciaKmRedondeada(ref, b.punto!);
                final x = da.compareTo(db);
                return x != 0 ? x : b.vistosBuenos.compareTo(a.vistosBuenos);
              });
            return Column(children: [for (final s in orden.take(3)) TarjetaCerca(s)]);
          },
        ),

        TituloDiseno('Necesitan una mano', accion: ('Ver todo', () => irA(2))),
        Cargador<List<Publicacion>>(
          cargar: (st) => st.repo.publicaciones(emergencia: false),
          builder: (c, lista) {
            final pedidos = lista.where((p) => p.esPedido && !p.esColecta).toList();
            if (pedidos.isEmpty) {
              return const EstadoVacio(icono: Icons.diversity_3, texto: 'Todavía nadie ha pedido ayuda. ¡Buena señal!');
            }
            return Column(children: [for (final p in pedidos.take(2)) TarjetaPublicacion(p)]);
          },
        ),
      ]),
    );
  }
}

// ============================================================= emergencia

class EmergenciaScreen extends StatelessWidget {
  const EmergenciaScreen({super.key, required this.irA});
  final ValueChanged<int> irA;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    const rojo = Paleta.rojo;
    const rojoCat = (Color(0xFFE53935), Color(0xFFFDECEA));
    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: ListView(padding: const EdgeInsets.only(bottom: 110), children: [
        if (st.esBrigadista) ...[const PanelBrigadista(), const SizedBox(height: 12)],
        if (st.emergencia.mensaje != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(children: [
              Expanded(child: Text(st.emergencia.mensaje!, style: const TextStyle(fontSize: 15, color: Paleta.tinta))),
              BotonEscuchar('Emergencia. ${st.emergencia.titulo ?? ''}. ${st.emergencia.mensaje}', compacto: true),
            ]),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
                onPressed: () => abrirFormulario(context, TipoForm.necesitoAyuda),
                icon: const Icon(Icons.sos, size: 44),
                label: const Text('NECESITO AYUDA', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Funciona sin cuenta y sin internet.', textAlign: TextAlign.center, style: TextStyle(color: Paleta.gris)),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: AccesoCategoria(
                texto: 'Avisar de un vecino',
                icono: Icons.elderly,
                colores: rojoCat,
                onTap: () => abrirFormulario(context, TipoForm.reportarVulnerable),
              ),
            ),
            Expanded(
              child: AccesoCategoria(
                texto: 'Tengo algo para compartir',
                icono: Icons.inventory_2_outlined,
                colores: Paleta.verdeCat,
                onTap: () => abrirFormulario(context, TipoForm.ofrezcoRecurso),
              ),
            ),
            Expanded(child: AccesoCategoria(texto: 'Grupos de apoyo', icono: Icons.health_and_safety_outlined, colores: Paleta.azul, onTap: () => irA(1))),
            Expanded(child: AccesoCategoria(texto: 'Mapa de ayuda', icono: Icons.map_outlined, colores: Paleta.morado, onTap: () => irA(3))),
          ]),
        ),
        const SizedBox(height: 10),
        const AvisoAutoridades(),
        const SizedBox(height: 6),
        ListaAjustes(filas: [
          if (st.esOrganizacion || st.esModerador || st.esBrigadista)
            FilaAjuste(
              icono: Icons.dashboard_outlined,
              texto: 'Panel de coordinación',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PanelCoordinacionScreen())),
            ),
          FilaAjuste(
            icono: Icons.qr_code_scanner,
            texto: '¿Sin internet? Lleva mensajes por QR',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EscanearQrScreen())),
          ),
        ]),
        TituloDiseno('Pedidos de ayuda urgentes', accion: ('Ver todos', () => irA(2))),
        Cargador<List<Publicacion>>(
          cargar: (st) => st.repo.publicaciones(emergencia: true),
          builder: (c, lista) {
            final pedidos = lista.where((p) => p.esPedido).toList()
              ..sort((a, b) {
                final x = b.pesoPrioridad.compareTo(a.pesoPrioridad);
                return x != 0 ? x : b.creado.compareTo(a.creado);
              });
            if (pedidos.isEmpty) {
              return const EstadoVacio(icono: Icons.check_circle, texto: 'No hay pedidos abiertos por ahora.');
            }
            return Column(children: [for (final p in pedidos.take(5)) TarjetaPublicacion(p)]);
          },
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Paleta.rojo.withValues(alpha: 0.35), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: Paleta.rojoSuave,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.health_and_safety, color: Paleta.rojo, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Eres punto focal de tu brigada',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Paleta.rojoOscuro)),
                Text(st.modoEmergencia ? 'Modo crítico activo: coordina la ayuda y el reparto de recursos.' : 'Aquí llegan las alertas SOS de tus vecinos.',
                    style: const TextStyle(fontSize: 13, color: Paleta.tinta)),
              ]),
            ),
          ]),
        ),
        Cargador<List<Publicacion>>(
          // Una sola fuente de alertas: los SOS del botón de pánico (origen 'sos',
          // últimas 24 h, sin atender), haya o no emergencia activa.
          cargar: (st) => st.repo.alertasSos(),
          builder: (c, alertas) {
            if (alertas.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Sin alertas SOS abiertas. Todo tranquilo por ahora.', style: TextStyle(color: Paleta.gris)),
              );
            }
            return Column(children: [
              for (final p in alertas.take(4))
                ListTile(
                  leading: Icon(buscarCategoria(p.categoria, emergencia: true).icono, color: Paleta.rojo),
                  title: Text(p.titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  subtitle: Text([p.autorNombre ?? 'Vecino', if (p.sector != null) p.sector!, haceCuanto(p.creado)].join(' · ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => PublicacionDetalle(publicacion: p))),
                ),
            ]);
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PanelCoordinacionScreen())),
            icon: const Icon(Icons.dashboard_outlined),
            label: const Text('Panel de coordinación'),
          ),
        ),
      ]),
    );
  }
}

/// Prestador de servicios: muestra su oficio y sus Vistos Buenos.
class TarjetaPrestador extends StatelessWidget {
  const TarjetaPrestador({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Paleta.acentoSuave, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: Paleta.acento, borderRadius: BorderRadius.circular(15)),
          child: const Icon(Icons.handyman, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(st.especialidad ?? 'Prestador de servicios', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (st.logueado)
              Cargador<(List<Publicacion>, List<Servicio>)>(
                cargar: (st) => st.repo.misPublicaciones(),
                builder: (c, datos) {
                  final vb = datos.$2.fold<int>(0, (a, s) => a + s.vistosBuenos);
                  return Text('$vb Vistos Buenos vecinales · ${datos.$2.length} servicios publicados',
                      style: const TextStyle(color: Paleta.gris, fontSize: 13));
                },
              )
            else
              const Text('Crea tu cuenta para acumular reseñas del Visto Bueno Vecinal.',
                  style: TextStyle(color: Paleta.gris, fontSize: 13)),
          ]),
        ),
        IconButton(
          tooltip: 'Publicar mi servicio',
          onPressed: () => abrirFormulario(context, TipoForm.servicio),
          icon: const Icon(Icons.add_circle, color: Paleta.acentoOscuro, size: 30),
        ),
      ]),
    );
  }
}
