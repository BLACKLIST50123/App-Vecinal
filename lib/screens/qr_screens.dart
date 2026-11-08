import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/qr_codec.dart';
import '../data/repo.dart';
import '../state/app_state.dart';
import '../ui/widgets.dart';

/// DIFERENCIADOR · "Mula de datos" vecinal.
/// Sin internet, el pedido se convierte en un QR. Cualquier vecino lo
/// escanea (también sin internet) y su app lo envía cuando tenga señal.
/// Los IDs únicos evitan duplicados aunque varios vecinos lo escaneen.

class MostrarQrScreen extends StatelessWidget {
  const MostrarQrScreen({super.key, required this.datos});
  final Map<String, dynamic> datos;

  @override
  Widget build(BuildContext context) {
    final codigo = QrCodec.codificar(datos);
    final titulo = (datos['titulo'] ?? '') as String;
    const instrucciones = 'Pide a un vecino que abra Conecta Vecino, toque "Llevar mensajes" y escanee este código. '
        'Cuando él tenga internet, tu pedido se publicará automáticamente.';
    return Scaffold(
      appBar: AppBar(title: const Text('Compartir por QR')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Text(titulo, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Center(
            child: Semantics(
              label: 'Código QR del pedido: $titulo',
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: QrImageView(data: codigo, size: 300, backgroundColor: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(instrucciones, textAlign: TextAlign.center, style: TextStyle(fontSize: 17)),
          const Center(child: BotonEscuchar(instrucciones)),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Listo')),
        ]),
      ),
    );
  }
}

class EscanearQrScreen extends StatefulWidget {
  const EscanearQrScreen({super.key});

  @override
  State<EscanearQrScreen> createState() => _EscanearQrScreenState();
}

class _EscanearQrScreenState extends State<EscanearQrScreen> {
  final _control = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _procesando = false;

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  Future<void> _detectado(BarcodeCapture captura) async {
    if (_procesando) return;
    final texto = captura.barcodes.isEmpty ? null : captura.barcodes.first.rawValue;
    final datos = QrCodec.decodificar(texto);
    if (datos == null) return;
    _procesando = true;
    await _control.stop();
    if (!mounted) return;
    final st = context.read<AppState>();
    final nuevo = await st.repo.agregarDesdeQr(datos);
    await st.sincronizar(silencioso: true);
    if (!mounted) return;
    final enviado = !st.repo.pendientes.any((p) => p.id == datos['id']);
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(enviado ? Icons.check_circle : Icons.inventory, size: 48, color: const Color(0xFF2E7D32)),
        title: Text(!nuevo ? 'Ya tenías este pedido' : (enviado ? '¡Pedido enviado!' : '¡Pedido guardado!')),
        content: Text(
          '"${datos['titulo']}"\n\n'
          '${enviado ? 'Ya está publicado para todo el barrio. ¡Gracias por llevarlo!' : 'Se enviará automáticamente cuando tengas internet. Gracias por ser parte de la cadena.'}',
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Entendido'))],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Escanear pedido de un vecino')),
        body: Column(children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Apunta la cámara al código QR que te muestra tu vecino.', style: TextStyle(fontSize: 17), textAlign: TextAlign.center),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: MobileScanner(controller: _control, onDetect: _detectado),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      );
}

/// Publicaciones guardadas sin internet o traídas por QR.
class PendientesScreen extends StatelessWidget {
  const PendientesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final lista = List<EntradaPendiente>.of(st.repo.pendientes);
    return Scaffold(
      appBar: AppBar(title: const Text('Llevar mensajes')),
      body: ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        Card(
          color: const Color(0xFFEDE7F6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('¿Cómo funciona?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
              const SizedBox(height: 8),
              const Text(
                '1. Si no tienes internet, tu publicación se guarda en el teléfono.\n'
                '2. Muéstrala como código QR a un vecino.\n'
                '3. Él la escanea y su app la envía cuando tenga señal.',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const BotonEscuchar(
                'Cómo funciona. Uno: si no tienes internet, tu publicación se guarda en el teléfono. '
                'Dos: muéstrala como código QR a un vecino. Tres: él la escanea y su app la envía cuando tenga señal.',
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EscanearQrScreen())),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Escanear QR de un vecino'),
          ),
        ),
        TituloSeccion('Por enviar (${lista.length})',
            accion: lista.isEmpty || !st.online ? null : ('Enviar ahora', () => st.sincronizar())),
        if (lista.isEmpty)
          const EstadoVacio(icono: Icons.cloud_done, texto: 'Todo está enviado. No tienes nada pendiente.')
        else
          for (final e in lista)
            Card(
              child: ListTile(
                leading: Icon(e.viaQr ? Icons.qr_code_2 : Icons.schedule_send, size: 32),
                title: Text(e.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(e.error != null
                    ? 'No se pudo enviar: ${e.error}'
                    : (e.viaQr ? 'Lo traes de otro vecino' : 'Tu publicación')),
                trailing: Wrap(children: [
                  if (e.tabla == 'publicaciones')
                    IconButton(
                      tooltip: 'Mostrar QR',
                      icon: const Icon(Icons.qr_code_2),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => MostrarQrScreen(datos: {...e.datos, 'autor_nombre': e.datos['autor_nombre'] ?? st.nombre}),
                      )),
                    ),
                  IconButton(
                    tooltip: 'Eliminar',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('¿Eliminar esta publicación pendiente?'),
                          content: const Text('No se enviará.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
                            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí, eliminar')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await st.repo.eliminarPendiente(e);
                        st.refrescar();
                      }
                    },
                  ),
                ]),
              ),
            ),
      ]),
    );
  }
}
