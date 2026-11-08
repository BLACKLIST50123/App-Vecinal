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

  group('Modo emergencia', () {
    test('la emergencia se identifica por la hora en que se activó', () {
      final e = EstadoEmergencia.fromMap({'activa': true, 'titulo': 'Lluvias', 'actualizado_en': '2026-11-08T10:00:00Z'});
      expect(e.clave, '2026-11-08T10:00:00.000Z');
      expect(const EstadoEmergencia.inactiva().clave, isNull);
    });

    test('el mapa de emergencia muestra solo los pedidos de ESTA emergencia', () {
      final desde = DateTime.utc(2026, 11, 8, 15);
      final puntos = armarPuntosEmergencia(
        grupos: [
          Servicio(id: 'g1', categoria: 'albergue', titulo: 'Albergue', esEmergencia: true, lat: -9.08, lng: -78.58),
          Servicio(id: 's1', categoria: 'gasfiteria', titulo: 'Gasfitero', lat: -9.08, lng: -78.58),
        ],
        pedidos: [
          Publicacion(id: 'viejo', tipo: 'pido', categoria: 'rescate', titulo: 'De ayer', esEmergencia: true,
              lat: -9.08, lng: -78.58, creado: desde.subtract(const Duration(days: 1)).toLocal()),
          Publicacion(id: 'nuevo', tipo: 'pido', categoria: 'rescate', titulo: 'Ahora', esEmergencia: true,
              lat: -9.08, lng: -78.58, creado: desde.add(const Duration(minutes: 10)).toLocal()),
          Publicacion(id: 'oferta', tipo: 'ofrezco', categoria: 'recurso', titulo: 'Tengo agua', esEmergencia: true,
              lat: -9.08, lng: -78.58, creado: desde.add(const Duration(minutes: 5)).toLocal()),
        ],
        desde: desde,
      );
      expect(puntos.map((p) => (p.id, p.tipo)).toList(), [('g1', TipoPunto.grupo), ('nuevo', TipoPunto.emergencia)]);
    });

    test('en el mapa, los grupos de apoyo tienen su propio tipo', () {
      final puntos = armarPuntos(
        servicios: [Servicio(id: 'g1', categoria: 'albergue', titulo: 'Albergue', esEmergencia: true, lat: -9.08, lng: -78.58)],
        publicaciones: const [],
        emergencias: const [],
      );
      expect(puntos.single.tipo, TipoPunto.grupo);
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
