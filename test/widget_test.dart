import 'package:app_vecinal/config.dart';
import 'package:app_vecinal/data/qr_codec.dart';
import 'package:app_vecinal/main.dart';
import 'package:app_vecinal/models.dart';
import 'package:app_vecinal/screens/roles.dart';
import 'package:app_vecinal/util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Sin credenciales muestra cómo ejecutar la app', (tester) async {
    await tester.pumpWidget(const SinCredenciales());
    expect(find.textContaining('Faltan SUPABASE_URL'), findsOneWidget);
  });

  group('Mula de datos QR', () {
    final datos = {
      'id': nuevoId(),
      'tipo': 'pido',
      'categoria': 'agua_alimento',
      'titulo': 'Familia sin agua',
      'es_emergencia': true,
      'prioridad': 'critica',
      'autor_id': 'no-debe-viajar',
      'estado': 'resuelta',
      'atendido_por': 'no-debe-viajar',
    };

    test('ida y vuelta conserva el contenido', () {
      final d = QrCodec.decodificar(QrCodec.codificar(datos))!;
      expect(d['id'], datos['id']);
      expect(d['titulo'], 'Familia sin agua');
      expect(d['prioridad'], 'critica');
    });

    test('quien lleva el QR no queda como autor ni puede cambiar el estado', () {
      final d = QrCodec.decodificar(QrCodec.codificar(datos))!;
      expect(d['origen'], 'qr');
      expect(d['autor_id'], isNull);
      expect(d.containsKey('estado'), isFalse);
      expect(d.containsKey('atendido_por'), isFalse);
    });

    test('rechaza QR ajenos o inválidos', () {
      expect(QrCodec.decodificar('https://ejemplo.com'), isNull);
      expect(QrCodec.decodificar('{"app":"otra","d":{}}'), isNull);
      expect(QrCodec.decodificar('{"app":"vecinal","v":1,"d":{"id":"x","tipo":"pido","categoria":"a","titulo":"abc"}}'), isNull);
    });
  });

  group('Reconocimiento vecinal', () {
    test('niveles según ayudas confirmadas', () {
      expect(Nivel.de(0).nombre, 'Vecino nuevo');
      expect(Nivel.de(1).nombre, 'Buen vecino');
      expect(Nivel.de(3).nombre, 'Vecino solidario');
      expect(Nivel.de(6).nombre, 'Vecino solidario');
      expect(Nivel.de(7).nombre, 'Corazón del barrio');
      expect(Nivel.de(40).nombre, 'Guardián del barrio');
    });

    test('siguiente nivel y fin de la escala', () {
      expect(Nivel.siguiente(1)!.nombre, 'Vecino solidario');
      expect(Nivel.siguiente(15), isNull);
    });
  });

  group('Geolocalización', () {
    test('ID único con formato UUID v4', () {
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(nuevoId()), isTrue);
    });

    test('Casco Urbano y Nuevo Chimbote están en la zona; Lima no', () {
      expect(enZona(Zona.sectores['Casco Urbano']!), isTrue);
      expect(enZona(Zona.sectores['Buenos Aires']!), isTrue);
      expect(enZona(const Punto(-12.0464, -77.0428)), isFalse);
    });

    test('la ubicación pública es aproximada: no exacta y a menos de 300 m', () {
      const casa = Punto(-9.09951, -78.56823);
      for (var i = 0; i < 200; i++) {
        final p = aproximar(casa);
        expect(distanciaKm(casa, p), lessThan(0.3));
        expect(p.lat == casa.lat && p.lng == casa.lng, isFalse);
      }
    });

    test('distancia aproximada correcta', () {
      final km = distanciaKm(Zona.sectores['Casco Urbano']!, Zona.sectores['Buenos Aires']!);
      expect(km, inInclusiveRange(7, 10));
    });
  });

  group('Roles simplificados', () {
    test('solo existen 2 roles elegibles: vecino y brigadista', () {
      expect(roles.length, 2);
      expect(roles.map((r) => r.id).toList(), ['vecino', 'brigadista']);
    });
  });

  group('Pedidos de Servicio y Aportes', () {
    test('creación y serialización de PedidoServicio', () {
      final pedido = PedidoServicio(
        id: 'p-123',
        servicioId: 's-456',
        prestadorId: 'user-prestador',
        clienteId: 'user-cliente',
        clienteNombre: 'María',
        clienteTelefono: '987654321',
        clienteSector: 'Casco Urbano',
        detalle: 'Reparación de cañería en la cocina',
        fechaDeseada: 'Mañana a las 10 am',
      );

      expect(pedido.esPendiente, isTrue);
      expect(pedido.estadoLegible, 'Pendiente');

      final map = pedido.toInsert();
      expect(map['id'], 'p-123');
      expect(map['servicio_id'], 's-456');
      expect(map['prestador_id'], 'user-prestador');
      expect(map['cliente_nombre'], 'María');
      expect(map['detalle'], 'Reparación de cañería en la cocina');
      expect(map['estado'], 'pendiente');

      final reconstruido = PedidoServicio.fromMap({
        'id': 'p-123',
        'servicio_id': 's-456',
        'prestador_id': 'user-prestador',
        'cliente_nombre': 'María',
        'detalle': 'Reparación de cañería en la cocina',
        'estado': 'aceptado',
        'servicios': {'titulo': 'Gasfitería a domicilio'},
      });

      expect(reconstruido.esAceptado, isTrue);
      expect(reconstruido.estadoLegible, 'Aceptado');
      expect(reconstruido.servicioTitulo, 'Gasfitería a domicilio');
    });

    test('Servicio soporta estado activo/pausado', () {
      final s = Servicio(
        id: 's-1',
        categoria: 'gasfiteria',
        titulo: 'Gasfitero del barrio',
        activo: true,
      );
      expect(s.activo, isTrue);
      expect(s.toInsert()['activo'], isTrue);

      final sPausado = Servicio.fromMap({
        'id': 's-2',
        'categoria': 'gasfiteria',
        'titulo': 'Gasfitero del barrio',
        'activo': false,
      });
      expect(sPausado.activo, isFalse);
    });
  });
}
