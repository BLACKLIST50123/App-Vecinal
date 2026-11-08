import 'package:app_vecinal/features/emergencia/emergencia_screen.dart';
import 'package:app_vecinal/features/emergencia/pedidos_emergencia.dart';
import 'package:app_vecinal/features/emergencia/pedir_ayuda_rapido.dart';
import 'package:app_vecinal/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final desde = DateTime.utc(2026, 11, 8, 15);
  Publicacion pedido(String id, {String? autor, int minutos = 10, String tipo = 'pido', String estado = 'abierta', String origen = 'app'}) =>
      Publicacion(
        id: id,
        tipo: tipo,
        categoria: 'rescate',
        titulo: id,
        autorId: autor,
        estado: estado,
        origen: origen,
        esEmergencia: true,
        creado: desde.add(Duration(minutes: minutos)).toLocal(),
      );

  group('Pedir ayuda rápido', () {
    test('las situaciones graves son muy urgentes', () {
      expect(gravedadPedido(situacionGrave: true), 'critica');
    });

    test('el texto puede volverlo muy urgente', () {
      expect(gravedadPedido(situacionGrave: false, texto: 'Necesito agua, hay un herido en casa'), 'critica');
      expect(gravedadPedido(situacionGrave: false, texto: 'Necesito agua para mañana'), 'alta');
    });
  });

  group('Pedidos de esta emergencia', () {
    test('solo los abiertos y creados desde que se activó', () {
      final lista = filtrarPedidosEmergencia([
        pedido('viejo', minutos: -60),
        pedido('nuevo'),
        pedido('resuelto', estado: 'resuelta'),
        pedido('oferta', tipo: 'ofrezco'),
        pedido('nuevo'), // repetido (SOS y emergencia)
      ], desde: desde);
      expect(lista.map((p) => p.id).toList(), ['nuevo']);
    });
  });

  group('Contador de vecinos', () {
    test('suma "Necesito ayuda", SOS y pedidos sin repetir a nadie', () {
      final r = contarVecinos(
        bien: {'ana', 'luis', 'rosa'},
        ayuda: {'pedro'},
        pedidos: [
          pedido('sos-rosa', autor: 'rosa', origen: 'sos'), // dijo "bien" pero luego mandó SOS
          pedido('p-pedro', autor: 'pedro'), // ya contado
          pedido('sin-cuenta'), // sin cuenta
        ],
      );
      expect(r.bien, 2); // ana y luis
      expect(r.ayuda, 3); // pedro, rosa y el de sin cuenta
    });
  });
}
