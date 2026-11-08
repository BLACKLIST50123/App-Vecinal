import 'package:app_vecinal/features/inicio/mapa_inicio.dart';
import 'package:app_vecinal/features/inicio/pulso.dart';
import 'package:app_vecinal/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pulso del barrio', () {
    final hace = DateTime.now().toUtc().subtract(const Duration(minutes: 5)).toIso8601String();

    test('arma mensajes sin nombres a partir de apoyos, pedidos y servicios', () {
      final e = armarPulso(
        apoyos: [
          {'created_at': hace, 'publicaciones': {'categoria': 'movilidad', 'sector': 'Bellamar', 'es_emergencia': false}},
        ],
        publicaciones: [
          {'tipo': 'pido', 'categoria': 'herramientas', 'sector': 'Casco Urbano', 'created_at': hace},
          {'tipo': 'pido', 'categoria': 'colecta', 'sector': 'Bellamar', 'created_at': hace},
        ],
        servicios: [
          {'categoria': 'gasfiteria', 'sector': null, 'created_at': hace},
        ],
      );
      final textos = e.map((x) => x.texto).toList();
      expect(textos, contains(startsWith('un vecino de Bellamar recibió apoyo')));
      expect(textos, contains(startsWith('alguien de Casco Urbano pidió ayuda')));
      expect(textos, contains('comenzó una colecta solidaria en Bellamar'));
      expect(textos, contains(startsWith('se publicó un nuevo servicio')));
    });

    test('lo tuyo pendiente (sin señal) va primero', () {
      final e = armarPulso(
        apoyos: const [],
        publicaciones: [
          {'tipo': 'pido', 'categoria': 'ayuda', 'created_at': hace},
        ],
        servicios: const [],
        pendientes: ['Necesito una escalera'],
      );
      expect(e.first.propio, isTrue);
      expect(e.first.texto, contains('se enviará cuando vuelva la señal'));
    });

    test('sin movimientos no hay mensajes', () {
      expect(armarPulso(apoyos: const [], publicaciones: const [], servicios: const []), isEmpty);
    });
  });

  group('Mapa del Inicio', () {
    test('separa servicios, productos, peticiones y emergencias', () {
      final puntos = armarPuntos(
        servicios: [
          Servicio(id: 's1', categoria: 'gasfiteria', titulo: 'Gasfitero', lat: -9.08, lng: -78.58),
          Servicio(id: 's2', categoria: 'panaderia', titulo: 'Pan', lat: -9.08, lng: -78.58),
          Servicio(id: 's3', categoria: 'otro', titulo: 'Sin ubicación'),
        ],
        publicaciones: [
          Publicacion(id: 'p1', tipo: 'pido', categoria: 'herramientas', titulo: 'Escalera', lat: -9.08, lng: -78.58),
          Publicacion(id: 'p2', tipo: 'pido', categoria: 'colecta', titulo: 'Colecta', lat: -9.08, lng: -78.58),
          Publicacion(id: 'p3', tipo: 'pido', categoria: 'ayuda', titulo: 'Ya atendida', estado: 'resuelta', lat: -9.08, lng: -78.58),
        ],
        emergencias: [
          Publicacion(id: 'e1', tipo: 'pido', categoria: 'sos_medico', titulo: 'SOS', origen: 'sos', lat: -9.08, lng: -78.58),
        ],
      );
      expect(puntos.map((p) => (p.id, p.tipo)).toList(), [
        ('s1', TipoPunto.servicio),
        ('s2', TipoPunto.producto),
        ('e1', TipoPunto.emergencia),
        ('p1', TipoPunto.peticion),
      ]);
    });
  });
}
