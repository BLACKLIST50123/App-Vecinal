import 'package:app_vecinal/services/notificaciones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Notificaciones', () {
    test('los avisos de emergencia vienen encendidos por defecto', () {
      final criticos = TipoAviso.values.where((t) => t.critico).toList();
      expect(criticos, containsAll([TipoAviso.emergencia, TipoAviso.sosCercano]));
      expect(criticos.every((t) => t.porDefecto), isTrue);
    });

    test('el foro viene apagado para no saturar', () {
      expect(TipoAviso.foro.porDefecto, isFalse);
      expect(TipoAviso.foro.critico, isFalse);
    });

    test('cada aviso tiene título y descripción para el vecino', () {
      for (final t in TipoAviso.values) {
        expect(t.titulo, isNotEmpty);
        expect(t.descripcion, isNotEmpty);
      }
    });
  });
}
