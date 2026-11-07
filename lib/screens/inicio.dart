import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';
import 'confianza.dart';
import 'publicar.dart';
import 'qr_screens.dart';
import 'tutorial.dart';

class _AccionGrande extends StatelessWidget {
  const _AccionGrande({required this.icono, required this.texto, required this.onTap});
  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final fondo = esquema.primaryContainer;
    final frente = esquema.onPrimaryContainer;
    return Material(
      color: fondo,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icono, size: 36, color: frente),
            const SizedBox(height: 6),
            Text(texto, textAlign: TextAlign.center,
                style: TextStyle(color: frente, fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
        ),
      ),
    );
  }
}

class _Rejilla extends StatelessWidget {
  const _Rejilla(this.hijos);
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final columnas = c.maxWidth > 700 ? 4 : (c.maxWidth > 420 ? 3 : 2);
        final ancho = (c.maxWidth - 24 - (columnas - 1) * 12) / columnas;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [for (final h in hijos) SizedBox(width: ancho, child: h)],
          ),
        );
      });
}

// ============================================================== día a día

class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key, required this.irA});
  final ValueChanged<int> irA;

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final saludo = 'Hola, ${st.nombre}';
    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(saludo, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                Text('¿Qué necesitas hoy en tu barrio de ${Zona.nombre}?', style: Theme.of(context).textTheme.titleMedium),
              ]),
            ),
            BotonEscuchar(
              '$saludo. Aquí puedes encontrar oficios recomendados por tus vecinos, '
              'pedir u ofrecer favores sin dinero y ver todo en el mapa. '
              'Para publicar, toca el botón Publicar abajo a la derecha.',
              compacto: true,
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _Rejilla([
          _AccionGrande(icono: Icons.storefront, texto: 'Servicios y productos', onTap: () => irA(1)),
          _AccionGrande(icono: Icons.front_hand, texto: 'Pedir un favor', onTap: () => abrirFormulario(context, TipoForm.pidoFavor)),
          _AccionGrande(icono: Icons.volunteer_activism, texto: 'Ofrecer ayuda', onTap: () => abrirFormulario(context, TipoForm.ofrezcoFavor)),
          _AccionGrande(icono: Icons.map, texto: 'Ver en el mapa', onTap: () => irA(3)),
          _AccionGrande(
            icono: Icons.qr_code_scanner,
            texto: 'Llevar mensajes (QR)',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendientesScreen())),
          ),
          _AccionGrande(
            icono: Icons.help_outline,
            texto: 'Cómo usar la app',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TutorialScreen())),
          ),
        ]),
        TituloSeccion('Mejor recomendados', accion: ('Ver todos', () => irA(1))),
        Cargador<List<Servicio>>(
          cargar: (st) => st.repo.servicios(emergencia: false),
          builder: (c, lista) {
            final top = [...lista]..sort((a, b) => b.vistosBuenos.compareTo(a.vistosBuenos));
            if (top.isEmpty) return const EstadoVacio(icono: Icons.handyman, texto: 'Aún no hay servicios publicados.');
            return Column(children: [for (final s in top.take(3)) TarjetaServicio(s)]);
          },
        ),
        TituloSeccion('Lo último en la Cadena de Favores', accion: ('Ver todo', () => irA(2))),
        Cargador<List<Publicacion>>(
          cargar: (st) => st.repo.publicaciones(emergencia: false),
          builder: (c, lista) {
            if (lista.isEmpty) return const EstadoVacio(icono: Icons.diversity_3, texto: 'Aún no hay favores publicados.');
            return Column(children: [for (final p in lista.take(3)) TarjetaPublicacion(p)]);
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
    const rojo = Color(0xFFB71C1C);
    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
        const BannerEmergencia(grande: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          child: Text('Funciona sin cuenta y sin internet.', textAlign: TextAlign.center),
        ),
        const SizedBox(height: 12),
        _Rejilla([
          _AccionGrande(
            icono: Icons.elderly,
            texto: 'Reportar vecino vulnerable',
            onTap: () => abrirFormulario(context, TipoForm.reportarVulnerable),
          ),
          _AccionGrande(
            icono: Icons.inventory_2,
            texto: 'Ofrezco un recurso',
            onTap: () => abrirFormulario(context, TipoForm.ofrezcoRecurso),
          ),
          _AccionGrande(icono: Icons.health_and_safety, texto: 'Grupos de apoyo', onTap: () => irA(1)),
          _AccionGrande(icono: Icons.map, texto: 'Mapa de ayuda', onTap: () => irA(3)),
        ]),
        const SizedBox(height: 8),
        const AvisoAutoridades(),
        if (st.esOrganizacion || st.esModerador)
          Card(
            child: ListTile(
              leading: const Icon(Icons.dashboard, size: 36),
              title: const Text('Panel de coordinación', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Pendientes, en atención, verificados y reportes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PanelCoordinacionScreen())),
            ),
          ),
        Card(
          color: const Color(0xFFEDE7F6),
          child: ListTile(
            leading: const Icon(Icons.qr_code_2, size: 40, color: Color(0xFF4A148C)),
            title: const Text('¿Sin internet? Lleva mensajes por QR',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            subtitle: const Text('Escanea el pedido de un vecino sin señal y la app lo enviará cuando tú tengas internet.',
                style: TextStyle(color: Colors.black87)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EscanearQrScreen())),
          ),
        ),
        TituloSeccion('Pedidos de ayuda urgentes', accion: ('Ver todos', () => irA(2))),
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
