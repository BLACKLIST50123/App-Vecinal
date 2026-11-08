import 'package:app_vecinal/features/inicio/mapa_inicio.dart';
import 'package:app_vecinal/features/inicio/pulso.dart';
import 'package:app_vecinal/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Buenas noticias del barrio (solo casos de éxito)', () {
    final hace = DateTime.now().toUtc().subtract(const Duration(minutes: 5)).toIso8601String();
    final antes = DateTime.now().toUtc().subtract(const Duration(hours: 3)).toIso8601String();

    test('textos cortos: compró un servicio o producto, recibió ayuda, SOS atendido por quién', () {
      final e = armarPulso(
        recomendaciones: [
          {'created_at': hace, 'autor': {'sector': 'Miraflores Alto'}, 'servicios': {'categoria': 'gasfiteria'}},
          {'created_at': antes, 'autor': {'sector': 'Bellamar'}, 'servicios': {'categoria': 'panaderia'}},
        ],
        agradecimientos: [
          {'created_at': antes, 'publicaciones': {'categoria': 'herramientas', 'sector': 'Villa María', 'origen': 'app'}},
        ],
        atendidos: [
          {'origen': 'sos', 'categoria': 'inundacion', 'sector': 'Bellamar', 'created_at': antes, 'atendido_por': 'b1'},
          {'origen': 'sos', 'categoria': 'salud', 'sector': 'La Florida', 'created_at': antes, 'atendio': {'rol': 'organizacion'}, 'atendido_por': 'o1'},
        ],
        brigadistas: {'b1'},
      );
      final textos = e.map((x) => x.texto).toList();
      expect(textos, contains(startsWith('Vecino de Miraflores Alto compró un servicio de')));
      expect(textos, contains(startsWith('Vecino de Bellamar compró un producto de')));
      expect(textos, contains(startsWith('Vecino de Villa María recibió ayuda:')));
      expect(textos, contains('El SOS de un vecino de Bellamar fue atendido por un brigadista'));
      expect(textos, contains('El SOS de un vecino de La Florida fue atendido por una organización'));
    });

    test('se intercalan: servicio, solidaridad, emergencia, servicio...', () {
      final e = armarPulso(
        recomendaciones: [
          {'created_at': hace, 'servicios': {'categoria': 'gasfiteria'}},
          {'created_at': antes, 'servicios': {'categoria': 'electricidad'}},
        ],
        agradecimientos: [
          {'created_at': hace, 'publicaciones': {'categoria': 'ayuda', 'origen': 'app'}},
        ],
        atendidos: [
          {'origen': 'sos', 'categoria': 'salud', 'created_at': hace},
        ],
      );
      expect(e.map((x) => x.tipo).toList(), [TipoExito.servicio, TipoExito.solidaridad, TipoExito.sos, TipoExito.servicio]);
    });

    test('sin casos de éxito no hay mensajes', () {
      expect(armarPulso(recomendaciones: const [], agradecimientos: const [], atendidos: const []), isEmpty);
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
