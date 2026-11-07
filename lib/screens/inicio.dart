import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/diseno.dart';
import '../ui/tema.dart';
import '../ui/widgets.dart';
import '../util.dart';
import 'confianza.dart';
import 'publicar.dart';
import 'qr_screens.dart';
import 'tutorial.dart';

typedef IrA = void Function(int tab, {String? grupo, String? consulta});

// ============================================================== día a día

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key, required this.irA});
  final IrA irA;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final resumenVoz = 'Hola ${st.nombre}. Aquí encuentras servicios y productos de tu barrio recomendados por tus vecinos, '
        'puedes pedir o dar una mano sin dinero y ver todo en el mapa. Para publicar, toca el botón Publicar.';

    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: ListView(padding: const EdgeInsets.only(bottom: 110), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
          child: Row(children: [
            PildoraUbicacion(
              texto: st.sector ?? Zona.nombre,
              onTap: () => irA(3),
            ),
            const Spacer(),
            BotonEscuchar(resumenVoz, compacto: true),
          ]),
        ),
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
          colores: const [Paleta.verde, Paleta.verdeClaro],
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

        TituloDiseno('Vecinos que necesitan una mano', accion: ('Ver todo', () => irA(2))),
        Cargador<List<Publicacion>>(
          cargar: (st) => st.repo.publicaciones(emergencia: false),
          builder: (c, lista) {
            final pedidos = lista.where((p) => p.esPedido && !p.esColecta).toList();
            final colectas = lista.where((p) => p.esColecta).toList();
            if (pedidos.isEmpty && colectas.isEmpty) {
              return const EstadoVacio(icono: Icons.diversity_3, texto: 'Todavía nadie ha pedido ayuda. ¡Buena señal!');
            }
            return Column(children: [
              for (final p in pedidos.take(2)) TarjetaPublicacion(p),
              if (colectas.isNotEmpty) ...[
                const TituloDiseno('Colectas del barrio', ceja: 'Responsabilidad social'),
                SizedBox(
                  height: 206,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [for (final p in colectas) TarjetaColecta(p)],
                  ),
                ),
              ],
            ]);
          },
        ),

        const TituloDiseno('Atajos'),
        ListaAjustes(filas: [
          FilaAjuste(
            icono: Icons.qr_code_scanner,
            texto: 'Llevar mensajes por QR',
            valor: 'Sin internet',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendientesScreen())),
          ),
          FilaAjuste(icono: Icons.shield_outlined, texto: 'Ayudar con seguridad', onTap: () => mostrarConsejos(context)),
          FilaAjuste(
            icono: Icons.help_outline,
            texto: 'Cómo usar la app',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TutorialScreen())),
          ),
        ]),
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
    const rojoCat = (Color(0xFFB71C1C), Color(0xFFFDE7E7));
    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: ListView(padding: const EdgeInsets.only(bottom: 110), children: [
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
          if (st.esOrganizacion || st.esModerador)
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
