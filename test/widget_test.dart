import 'package:app_vecinal/config.dart';
import 'package:app_vecinal/data/qr_codec.dart';
import 'package:app_vecinal/data/repo.dart';
import 'package:app_vecinal/data/sugerencias.dart';
import 'package:app_vecinal/features/solidaridad/clasificador.dart';
import 'package:app_vecinal/features/sos/sos_tipos.dart';
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

  group('Modo SOS', () {
    test('6 emergencias nacionales en la pantalla principal, sin "falta de agua"', () {
      expect(TipoSos.principales.map((t) => t.titulo),
          ['Emergencia Médica', 'Inseguridad', 'Lluvia o Inundación', 'Incendio o Gas', 'Accidente', 'Sismo']);
      expect(TipoSos.values.any((t) => t.titulo.toLowerCase().contains('agua')), isFalse);
    });

    test('Inseguridad abre 4 subtipos', () {
      expect(TipoSos.inseguridad.abreSubmenu, isTrue);
      expect(TipoSos.deInseguridad.map((t) => t.titulo), ['Robo', 'Secuestro', 'Extorsión', 'Violencia']);
    });

    test('secuestro, extorsión y violencia son avisos reservados; robo no', () {
      expect(TipoSos.values.where((t) => t.reservado), [TipoSos.secuestro, TipoSos.extorsion, TipoSos.violencia]);
      expect(TipoSos.robo.reservado, isFalse);
    });

    test('desastres naturales en ámbar; el resto en rojo', () {
      expect(TipoSos.values.where((t) => t.advertencia), [TipoSos.inundacion, TipoSos.sismo]);
      expect(TipoSos.medico.color, ColoresSos.rojo);
    });

    test('las alertas vencen: 24 h las muy urgentes, 6 h las demás', () {
      expect(Repo.vigenciaSos('critica'), const Duration(hours: 24));
      expect(Repo.vigenciaSos('alta'), const Duration(hours: 6));
    });
  });

  group('Solidaridad: clasificador por palabras clave', () {
    test('detecta las 5 categorías del reto', () {
      expect(Clasificador.categoria('Necesito que me presten una escalera').categoria, 'herramientas');
      expect(Clasificador.categoria('¿Alguien me lleva al hospital el jueves?').categoria, 'movilidad');
      expect(Clasificador.categoria('Busco donación de útiles y cuadernos').categoria, 'donacion');
      expect(Clasificador.categoria('Quiero clases de inglés, enseño matemática').categoria, 'habilidad');
      expect(Clasificador.categoria('Ayuda para cargar muebles en la mudanza').categoria, 'ayuda');
    });

    test('si no reconoce nada queda en Otro (no detectada)', () {
      final c = Clasificador.categoria('Necesito algo raro');
      expect(c.categoria, 'otros');
      expect(c.detectada, isFalse);
    });

    test('detecta urgencia por palabras', () {
      expect(Clasificador.esUrgente('Lo necesito hoy, es urgente'), isTrue);
      expect(Clasificador.esUrgente('Cuando puedas, el próximo mes'), isFalse);
    });

    test('fecha y hora legibles', () {
      final ahora = DateTime.now();
      expect(fechaHora(DateTime(ahora.year, ahora.month, ahora.day, 9, 5)), 'Hoy 09:05');
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

    test('cada rango tiene su propio ícono y su posición en la escala', () {
      expect(Nivel.todos.map((n) => n.icono).toSet().length, Nivel.todos.length);
      expect(Nivel.de(0).indice, 0);
      expect(Nivel.de(7).indice, 3);
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
