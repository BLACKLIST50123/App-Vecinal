import 'package:app_vecinal/features/emergencia/panel_coordinacion.dart';
import 'package:app_vecinal/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final desde = DateTime.utc(2026, 11, 8, 15);
  Publicacion sos(String id, int minutos) => Publicacion(
        id: id,
        tipo: 'pido',
        categoria: 'sos_medico',
        titulo: 'Emergencia médica',
        origen: 'sos',
        sector: 'Villa María',
        lat: -9.08,
        lng: -78.58,
        creado: desde.add(Duration(minutes: minutos)).toLocal(),
      );

  test('separa los SOS de esta emergencia y los anteriores, del más reciente al más antiguo', () {
    final g = separarSos([sos('a', -30), sos('b', 5), sos('c', 20), sos('d', -90)], desde: desde);
    expect(g.ahora.map((p) => p.id).toList(), ['c', 'b']);
    expect(g.antes.map((p) => p.id).toList(), ['a', 'd']);
  });

  test('sin emergencia activa todos van juntos', () {
    final g = separarSos([sos('a', -30), sos('b', 5)]);
    expect(g.ahora, isEmpty);
    expect(g.antes.map((p) => p.id).toList(), ['b', 'a']);
  });

  test('el mensaje para derivar lleva sector, hora y ubicación', () {
    final t = textoDerivarSos(sos('a', 0));
    expect(t, contains('Villa María'));
    expect(t, contains('maps.google.com/?q=-9.08,-78.58'));
  });
}
