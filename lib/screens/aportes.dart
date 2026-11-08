import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../ui/diseno.dart';
import '../ui/tema.dart';
import '../ui/widgets.dart';
import '../util.dart';
import 'auth_screen.dart';
import 'detalles.dart';
import 'publicar.dart';

/// Pestaña "Mis aportes": Centro de administración del prestador de servicios,
/// productor o docente del barrio. Permite gestionar pedidos recibidos y
/// administrar lo que se ha publicado (crear, editar, pausar, borrar).
class MisAportesScreen extends StatefulWidget {
  const MisAportesScreen({super.key});

  @override
  State<MisAportesScreen> createState() => _MisAportesScreenState();
}

class _MisAportesScreenState extends State<MisAportesScreen> {
  int _subtab = 0; // 0: Pedidos recibidos, 1: Lo que ofrezco
  String _filtroPedido = 'todos'; // todos | pendiente | en_proceso | completado
  String _filtroOferta = 'todos'; // todos | servicios | productos | clases

  void _abrirPublicar(BuildContext context, {String grupo = 'servicios'}) {
    final st = context.read<AppState>();
    if (!st.logueado) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AuthScreen(
            mensaje: 'Para publicar un servicio, producto o clase necesitas una cuenta.',
          ),
        ),
      );
      return;
    }
    abrirFormulario(context, TipoForm.servicio);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();

    if (!st.logueado) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Paleta.linea),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Paleta.acentoSuave,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.storefront, size: 36, color: Paleta.acentoOscuro),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Ofrece lo que sabes hacer en tu barrio',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gasfitería, repostería, clases, costura o tu bodega. Con una cuenta gratis tus vecinos podrán encontrarte y pedirte directamente.',
                  style: TextStyle(color: Paleta.gris, fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())),
                  icon: const Icon(Icons.login),
                  label: const Text('Ingresar o crear mi cuenta'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () async => st.refrescar(),
      child: Cargador<(List<Servicio>, List<PedidoServicio>)>(
        claves: [st.version],
        cargar: (st) async {
          final servs = await st.repo.misServicios();
          final pedidos = await st.repo.pedidosRecibidos();
          return (servs, pedidos);
        },
        builder: (context, datos) {
          final (servs, pedidos) = datos;
          final totalVb = servs.fold<int>(0, (acc, s) => acc + s.vistosBuenos);
          final pedidosPendientes = pedidos.where((p) => p.esPendiente).length;

          // Si el usuario aún no tiene ningún servicio publicado
          if (servs.isEmpty && pedidos.isEmpty) {
            return _BienvenidaSinAportes(
              onCrearServicio: () => _abrirPublicar(context, grupo: 'servicios'),
              onCrearProducto: () => _abrirPublicar(context, grupo: 'productos'),
              onCrearClase: () => _abrirPublicar(context, grupo: 'clases'),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 110),
            children: [
              // -------------------------------- Tarjeta Resumen del Prestador
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Paleta.acentoSuave, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Paleta.linea),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Paleta.acentoOscuro,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.handyman, color: Colors.white, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'Prestador de servicios local',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (pedidosPendientes > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC2185B),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$pedidosPendientes ${pedidosPendientes == 1 ? 'pedido nuevo' : 'pedidos nuevos'}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      st.nombre,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Zona: ${st.sector ?? Zona.nombre}',
                      style: const TextStyle(color: Paleta.gris, fontSize: 14),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _MetricaAporte('${servs.length}', 'Publicaciones'),
                        const SizedBox(width: 12),
                        _MetricaAporte('${pedidos.length}', 'Pedidos'),
                        const SizedBox(width: 12),
                        _MetricaAporte('$totalVb', 'Vistos Buenos'),
                      ],
                    ),
                  ],
                ),
              ),

              // ----------------------- 3 Botones rápidos independientes
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _BotonAccesoRapido(
                        icono: Icons.handyman_outlined,
                        titulo: '+ Servicio',
                        subtitulo: 'Oficio / técnico',
                        color: Paleta.primario,
                        onTap: () => _abrirPublicar(context, grupo: 'servicios'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BotonAccesoRapido(
                        icono: Icons.shopping_basket_outlined,
                        titulo: '+ Producto',
                        subtitulo: 'Comida / bodega',
                        color: Paleta.acentoOscuro,
                        onTap: () => _abrirPublicar(context, grupo: 'productos'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _BotonAccesoRapido(
                        icono: Icons.school_outlined,
                        titulo: '+ Clase',
                        subtitulo: 'Taller / asesoría',
                        color: const Color(0xFF2E7D32),
                        onTap: () => _abrirPublicar(context, grupo: 'clases'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // -------------------------------- Selector de subpestaña
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<int>(
                  segments: [
                    ButtonSegment<int>(
                      value: 0,
                      label: Text('Pedidos recibidos (${pedidos.length})'),
                      icon: const Icon(Icons.inbox),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      label: Text('Lo que ofrezco (${servs.length})'),
                      icon: const Icon(Icons.storefront),
                    ),
                  ],
                  selected: {_subtab},
                  onSelectionChanged: (s) => setState(() => _subtab = s.first),
                ),
              ),

              const SizedBox(height: 12),

              // -------------------------------- Contenido de la subpestaña
              if (_subtab == 0)
                _SeccionPedidos(
                  pedidos: pedidos,
                  filtro: _filtroPedido,
                  onFiltro: (f) => setState(() => _filtroPedido = f),
                )
              else
                _SeccionLoQueOfrezco(
                  servicios: servs,
                  filtro: _filtroOferta,
                  onFiltro: (f) => setState(() => _filtroOferta = f),
                ),
            ],
          );
        },
      ),
    );
  }
}

// =====================================================================
// Métricas y Botones Rápidos
// =====================================================================

class _MetricaAporte extends StatelessWidget {
  const _MetricaAporte(this.valor, this.etiqueta);
  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Paleta.linea),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(etiqueta, style: const TextStyle(fontSize: 11, color: Paleta.gris, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _BotonAccesoRapido extends StatelessWidget {
  const _BotonAccesoRapido({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.color,
    required this.onTap,
  });

  final IconData icono;
  final String titulo;
  final String subtitulo;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Icon(icono, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                titulo,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                subtitulo,
                style: const TextStyle(color: Paleta.gris, fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Bienvenida cuando no hay aportes aún
// =====================================================================

class _BienvenidaSinAportes extends StatelessWidget {
  const _BienvenidaSinAportes({
    required this.onCrearServicio,
    required this.onCrearProducto,
    required this.onCrearClase,
  });

  final VoidCallback onCrearServicio;
  final VoidCallback onCrearProducto;
  final VoidCallback onCrearClase;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Paleta.linea),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Paleta.acentoSuave,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.storefront, color: Paleta.acentoOscuro, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('¿Qué sabes hacer?', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                        Text('Ofrécelo a tus vecinos de confianza', style: TextStyle(color: Paleta.gris, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Tu barrio necesita lo que ofreces. Al publicar, aparecerás en el catálogo de Servicios y tus vecinos podrán hacerte pedidos directo a tu teléfono o WhatsApp.',
                style: TextStyle(color: Paleta.tinta, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 20),
              const Text(
                'Elige qué quieres publicar hoy:',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 12),
              _OpcionCrear(
                icono: Icons.handyman,
                color: Paleta.primario,
                titulo: '+ Nuevo servicio',
                subtitulo: 'Gasfitería, electricidad, carpintería, cerrajería, costura...',
                onTap: onCrearServicio,
              ),
              const SizedBox(height: 10),
              _OpcionCrear(
                icono: Icons.shopping_basket,
                color: Paleta.acentoOscuro,
                titulo: '+ Nuevo producto',
                subtitulo: 'Comida casera, postres, pan, bodega, artesanía...',
                onTap: onCrearProducto,
              ),
              const SizedBox(height: 10),
              _OpcionCrear(
                icono: Icons.school,
                color: const Color(0xFF2E7D32),
                titulo: '+ Nueva clase o taller',
                subtitulo: 'Reforzamiento escolar, música, idiomas, computación...',
                onTap: onCrearClase,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Paleta.acentoSuave.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified, color: Paleta.acentoOscuro, size: 20),
                  SizedBox(width: 8),
                  Text('Visto Bueno Vecinal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Cada vecino satisfecho puede darte su "Visto Bueno". Mientras más recomendaciones tengas, más arriba aparecerás para todo el barrio.',
                style: TextStyle(fontSize: 13, color: Paleta.tinta, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OpcionCrear extends StatelessWidget {
  const _OpcionCrear({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final IconData icono;
  final Color color;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Paleta.linea),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icono, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                    const SizedBox(height: 2),
                    Text(subtitulo, style: const TextStyle(color: Paleta.gris, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Paleta.grisClaro),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Subpestaña 1: Pedidos Recibidos
// =====================================================================

class _SeccionPedidos extends StatelessWidget {
  const _SeccionPedidos({
    required this.pedidos,
    required this.filtro,
    required this.onFiltro,
  });

  final List<PedidoServicio> pedidos;
  final String filtro;
  final ValueChanged<String> onFiltro;

  @override
  Widget build(BuildContext context) {
    final opciones = const [
      ('todos', 'Todos'),
      ('pendiente', 'Pendientes'),
      ('en_proceso', 'En proceso'),
      ('completado', 'Completados'),
    ];

    final filtrados = pedidos.where((p) {
      if (filtro == 'todos') return true;
      if (filtro == 'pendiente') return p.esPendiente;
      if (filtro == 'en_proceso') return p.esAceptado || p.esEnProceso;
      if (filtro == 'completado') return p.esCompletado;
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilaPildoras(opciones: opciones, seleccion: filtro, onCambio: onFiltro),
        if (filtrados.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: EstadoVacio(
              icono: Icons.inbox_outlined,
              texto: 'No tienes pedidos con este filtro.\nCuando un vecino solicite uno de tus servicios, aparecerá aquí.',
            ),
          )
        else
          for (final p in filtrados) _TarjetaPedido(pedido: p),
      ],
    );
  }
}

class _TarjetaPedido extends StatelessWidget {
  const _TarjetaPedido({required this.pedido});
  final PedidoServicio pedido;

  void _cambiarEstado(BuildContext context, String nuevoEstado) async {
    final st = context.read<AppState>();
    try {
      await st.repo.cambiarEstadoPedido(pedido.id, nuevoEstado);
      avisar('Pedido marcado como: ${PedidoServicio(id: '', servicioId: '', prestadorId: '', clienteNombre: '', detalle: '', estado: nuevoEstado).estadoLegible}');
      st.refrescar();
    } catch (e) {
      avisar(traducirError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (colorTxt, colorFondo) = pedido.coloresEstado;
    final tel = pedido.clienteTelefono;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: pedido.esPendiente ? const Color(0xFFC2185B).withValues(alpha: 0.4) : Paleta.linea,
          width: pedido.esPendiente ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pedido.servicioTitulo ?? 'Servicio / Producto',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: colorFondo, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  pedido.estadoLegible,
                  style: TextStyle(color: colorTxt, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: Paleta.gris),
              const SizedBox(width: 4),
              Text(
                [pedido.clienteNombre, if (pedido.clienteSector != null) '(${pedido.clienteSector})'].join(' '),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              Text(
                haceCuanto(pedido.creado),
                style: const TextStyle(color: Paleta.gris, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Paleta.linea),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pedido.detalle, style: const TextStyle(fontSize: 14, height: 1.35)),
                if (pedido.fechaDeseada != null && pedido.fechaDeseada!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.event, size: 14, color: Paleta.acentoOscuro),
                      const SizedBox(width: 4),
                      Text(
                        'Para: ${pedido.fechaDeseada}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Paleta.acentoOscuro),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (tel != null && tel.isNotEmpty) ...[
                OutlinedButton.icon(
                  onPressed: () => llamar(tel),
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text('Llamar'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final msg = 'Hola ${pedido.clienteNombre}, te escribo de App Vecinal respecto a tu pedido de "${pedido.servicioTitulo ?? 'servicio'}": "${pedido.detalle}".';
                    abrirWhatsapp(tel, msg);
                  },
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('WhatsApp'),
                ),
              ],
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: 'Cambiar estado',
                onSelected: (v) => _cambiarEstado(context, v),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'aceptado',
                    child: ListTile(leading: Icon(Icons.check_circle_outline_rounded), title: Text('Aceptar pedido')),
                  ),
                  PopupMenuItem(
                    value: 'en_proceso',
                    child: ListTile(leading: Icon(Icons.local_shipping_outlined), title: Text('En camino / En proceso')),
                  ),
                  PopupMenuItem(
                    value: 'completado',
                    child: ListTile(leading: Icon(Icons.task_alt_rounded), title: Text('Marcar completado')),
                  ),
                  PopupMenuItem(
                    value: 'cancelado',
                    child: ListTile(leading: Icon(Icons.cancel_outlined), title: Text('Cancelar pedido')),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Paleta.acentoSuave,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Estado', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Paleta.acentoOscuro)),
                      Icon(Icons.arrow_drop_down, size: 18, color: Paleta.acentoOscuro),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Subpestaña 2: Lo Que Ofrezco (Mis Publicaciones)
// =====================================================================

class _SeccionLoQueOfrezco extends StatelessWidget {
  const _SeccionLoQueOfrezco({
    required this.servicios,
    required this.filtro,
    required this.onFiltro,
  });

  final List<Servicio> servicios;
  final String filtro;
  final ValueChanged<String> onFiltro;

  @override
  Widget build(BuildContext context) {
    final opciones = const [
      ('todos', 'Todos'),
      ('servicios', 'Servicios'),
      ('productos', 'Productos'),
      ('clases', 'Clases'),
    ];

    final filtrados = servicios.where((s) {
      if (filtro == 'todos') return true;
      return grupoServicio(s.categoria) == filtro;
    }).toList();

    return Column(
      children: [
        FilaPildoras(opciones: opciones, seleccion: filtro, onCambio: onFiltro),
        if (filtrados.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: EstadoVacio(
              icono: Icons.storefront_outlined,
              texto: 'No tienes publicaciones en esta categoría.',
            ),
          )
        else
          for (final s in filtrados) _TarjetaMiPublicacion(servicio: s),
      ],
    );
  }
}

class _TarjetaMiPublicacion extends StatelessWidget {
  const _TarjetaMiPublicacion({required this.servicio});
  final Servicio servicio;

  void _alternarPausa(BuildContext context, bool nuevoActivo) async {
    final st = context.read<AppState>();
    try {
      await st.repo.alternarActivoServicio(servicio.id, nuevoActivo);
      avisar(nuevoActivo ? 'Servicio activado y visible en el catálogo' : 'Servicio puesto en pausa');
      st.refrescar();
    } catch (e) {
      avisar(traducirError(e));
    }
  }

  void _editar(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ModalEditarServicio(servicio: servicio),
    );
  }

  void _eliminar(BuildContext context) async {
    final st = context.read<AppState>();
    final ok = await confirmarEliminar(context, st, 'servicios', servicio.id, esModeracion: false);
    if (ok) st.refrescar();
  }

  @override
  Widget build(BuildContext context) {
    final s = servicio;
    final grupo = grupoServicio(s.categoria);
    final (cTxt, cBg) = colorGrupo(grupo);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Paleta.linea),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: cBg, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  buscarCategoria(s.categoria).nombre,
                  style: TextStyle(color: cTxt, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.activo ? 'Activo' : 'En pausa',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: s.activo ? const Color(0xFF2E7D32) : Paleta.gris,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: s.activo,
                    onChanged: (v) => _alternarPausa(context, v),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(s.titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (s.descripcion != null && s.descripcion!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(s.descripcion!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Paleta.tinta, fontSize: 13)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if (s.precioRef != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.payments, size: 16, color: Paleta.primario),
                    const SizedBox(width: 4),
                    Text(s.precioRef!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.thumb_up, size: 15, color: Color(0xFF2E7D32)),
                  const SizedBox(width: 4),
                  Text('${s.vistosBuenos} Vistos Buenos', style: const TextStyle(fontSize: 13, color: Paleta.gris)),
                ],
              ),
              if (s.sector != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.place, size: 15, color: Paleta.gris),
                    const SizedBox(width: 4),
                    Text(s.sector!, style: const TextStyle(fontSize: 13, color: Paleta.gris)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _editar(context),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Editar'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ServicioDetalle(servicio: s))),
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('Ver cómo queda'),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Eliminar publicación',
                onPressed: () => _eliminar(context),
                icon: const Icon(Icons.delete_outline, color: Paleta.rojo),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Modal para Editar Servicio
// =====================================================================

class ModalEditarServicio extends StatefulWidget {
  const ModalEditarServicio({super.key, required this.servicio});
  final Servicio servicio;

  @override
  State<ModalEditarServicio> createState() => _ModalEditarServicioState();
}

class _ModalEditarServicioState extends State<ModalEditarServicio> {
  late final TextEditingController _titulo;
  late final TextEditingController _descripcion;
  late final TextEditingController _precio;
  late final TextEditingController _telefono;
  late final TextEditingController _horario;
  late String _categoria;
  String? _sector;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final s = widget.servicio;
    _titulo = TextEditingController(text: s.titulo);
    _descripcion = TextEditingController(text: s.descripcion ?? '');
    _precio = TextEditingController(text: s.precioRef ?? '');
    _telefono = TextEditingController(text: s.telefono ?? '');
    _horario = TextEditingController(text: s.horario ?? '');
    _categoria = s.categoria;
    _sector = s.sector;
  }

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    _precio.dispose();
    _telefono.dispose();
    _horario.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final t = _titulo.text.trim();
    if (t.length < 3) {
      avisar('El título debe tener al menos 3 caracteres.');
      return;
    }
    setState(() => _guardando = true);
    final st = context.read<AppState>();
    try {
      final cambios = <String, dynamic>{
        'titulo': t,
        'categoria': _categoria,
        'descripcion': _descripcion.text.trim().isEmpty ? null : _descripcion.text.trim(),
        'precio_ref': _precio.text.trim().isEmpty ? null : _precio.text.trim(),
        'telefono': _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
        'horario': _horario.text.trim().isEmpty ? null : _horario.text.trim(),
        'sector': _sector,
      };
      await st.repo.actualizarServicio(widget.servicio.id, cambios);
      if (mounted) {
        Navigator.pop(context);
        avisar('¡Cambios guardados con éxito!');
        st.refrescar();
      }
    } catch (e) {
      if (mounted) avisar(traducirError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 20,
          right: 20,
          top: 8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Editar publicación', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _titulo,
                decoration: const InputDecoration(labelText: 'Título del servicio o producto *'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  for (final c in categoriasServicio)
                    DropdownMenuItem(value: c.id, child: Text(c.nombre)),
                ],
                onChanged: (v) => setState(() => _categoria = v ?? _categoria),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descripcion,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descripción detallada', hintText: '¿Qué incluye tu servicio o qué vendes?'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _precio,
                      decoration: const InputDecoration(labelText: 'Precio referencial', hintText: 'Ej. S/ 25'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _telefono,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Teléfono / WhatsApp', hintText: '987654321'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _horario,
                decoration: const InputDecoration(labelText: 'Horario de atención', hintText: 'Ej. Lunes a Sábado de 8am a 6pm'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _sector,
                decoration: const InputDecoration(labelText: 'Sector o barrio'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todo el distrito')),
                  for (final s in Zona.sectores.keys)
                    DropdownMenuItem(value: s, child: Text(s)),
                ],
                onChanged: (v) => setState(() => _sector = v),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _guardando ? null : _guardar,
                child: Text(_guardando ? 'Guardando...' : 'Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

