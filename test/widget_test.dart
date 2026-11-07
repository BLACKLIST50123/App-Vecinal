import 'package:app_vecinal/config.dart';
import 'package:app_vecinal/data/qr_codec.dart';
import 'package:app_vecinal/data/sugerencias.dart';
import 'package:app_vecinal/main.dart';
import 'package:app_vecinal/models.dart';
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

  group('Publicar sin escribir', () {
    final favores = [for (final c in categoriasFavor) c.id];
    final servicios = [for (final c in categoriasServicio) c.id];
    final emergencia = [for (final c in categoriasEmergencia) c.id];

    test('el texto dictado elige la categoría', () {
      expect(sugerirCategoria('Necesito una escalera', favores), 'herramientas');
      expect(sugerirCategoria('necesito que alguien me lleve al hospital', favores), 'movilidad');
      expect(sugerirCategoria('Gasfitero a domicilio', servicios), 'gasfiteria');
      expect(sugerirCategoria('se malogró la luz de mi casa', servicios), 'electricidad');
      expect(sugerirCategoria('Necesitamos agua potable', emergencia), 'agua_alimento');
      expect(sugerirCategoria('Estamos ATRAPADOS', emergencia), 'rescate');
    });

    test('sin coincidencia clara no cambia la categoría', () {
      expect(sugerirCategoria('hola', favores), isNull);
      expect(sugerirCategoria('ab', favores), isNull);
      // "pan" no debe confundirse dentro de otra palabra que no empieza así
      expect(sugerirCategoria('compañero', servicios), isNull);
    });

    test('cada frase rápida usa una categoría válida de su formulario', () {
      final validas = {
        'pidoFavor': favores.where((c) => c != 'colecta'),
        'ofrezcoFavor': favores.where((c) => c != 'colecta'),
        'colecta': ['colecta'],
        'servicio': servicios,
        'grupoApoyo': [for (final c in categoriasApoyo) c.id],
        'necesitoAyuda': emergencia.where((c) => c != 'recurso' && c != 'vulnerable'),
        'reportarVulnerable': ['vulnerable'],
        'ofrezcoRecurso': emergencia.where((c) => c != 'vulnerable' && c != 'rescate'),
      };
      for (final e in frasesRapidas.entries) {
        for (final f in e.value) {
          expect(validas[e.key], contains(f.categoria), reason: '${e.key}: ${f.texto}');
        }
      }
    });

    test('el GPS sugiere el sector más cercano', () {
      expect(sectorMasCercano(Zona.sectores['Bellamar']!), 'Bellamar');
      expect(sectorMasCercano(const Punto(-9.0750, -78.5930)), 'Casco Urbano');
    });
  });
}
