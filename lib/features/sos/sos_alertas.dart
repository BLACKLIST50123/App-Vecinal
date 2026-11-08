import 'package:flutter/material.dart';

import '../../models.dart';
import '../../ui/widgets.dart';
import 'sos_tipos.dart';

/// Franja "Alertas SOS activas": hace visibles los SOS de las últimas 24 h
/// aunque la junta no haya activado el modo emergencia. Si no hay alertas,
/// no ocupa espacio.
class FranjaAlertasSos extends StatelessWidget {
  const FranjaAlertasSos({super.key, this.maximo = 2});
  final int maximo;

  @override
  Widget build(BuildContext context) => Cargador<List<Publicacion>>(
        cargar: (st) => st.repo.alertasSos(),
        builder: (context, alertas) {
          if (alertas.isEmpty) return const SizedBox.shrink();
          return Semantics(
            liveRegion: true,
            container: true,
            label: '${alertas.length} ${alertas.length == 1 ? 'alerta SOS activa' : 'alertas SOS activas'}',
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: ColoresSos.rojoSuave,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: ColoresSos.rojo, width: 2),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(color: ColoresSos.rojo, shape: BoxShape.circle),
                      child: const Center(
                        child: Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Alertas SOS activas (${alertas.length})',
                            style: const TextStyle(color: ColoresSos.rojoOscuro, fontSize: 17, fontWeight: FontWeight.w800)),
                        const Text('Vecinos que pidieron ayuda ahora', style: TextStyle(color: Color(0xFF5F6B66), fontSize: 13)),
                      ]),
                    ),
                    if (alertas.length > maximo)
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertasSosScreen())),
                        child: const Text('Ver todas'),
                      ),
                  ]),
                ),
                const SizedBox(height: 4),
                for (final p in alertas.take(maximo)) TarjetaPublicacion(p),
              ]),
            ),
          );
        },
      );
}

class AlertasSosScreen extends StatelessWidget {
  const AlertasSosScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Alertas SOS activas')),
        body: Cargador<List<Publicacion>>(
          cargar: (st) => st.repo.alertasSos(),
          builder: (context, alertas) => alertas.isEmpty
              ? const EstadoVacio(icono: Icons.check_circle, texto: 'No hay alertas SOS activas. ¡Todo tranquilo!')
              : ListView(padding: const EdgeInsets.only(top: 8, bottom: 32), children: [for (final p in alertas) TarjetaPublicacion(p)]),
        ),
      );
}
