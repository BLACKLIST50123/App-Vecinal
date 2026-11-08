import 'package:app_vecinal/features/sos/sos_atajo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Atajo de volumen para el SOS', () {
    test('3 pulsaciones seguidas abren el SOS', () {
      final t0 = DateTime(2026, 1, 1, 12);
      expect(AtajoVolumenSos.registrarPulsacion(ahora: t0), isFalse);
      expect(AtajoVolumenSos.registrarPulsacion(ahora: t0.add(const Duration(milliseconds: 400))), isFalse);
      expect(AtajoVolumenSos.registrarPulsacion(ahora: t0.add(const Duration(milliseconds: 800))), isTrue);
    });

    test('pulsaciones separadas por más de 2 s no lo abren', () {
      final t0 = DateTime(2026, 1, 1, 13);
      expect(AtajoVolumenSos.registrarPulsacion(ahora: t0), isFalse);
      expect(AtajoVolumenSos.registrarPulsacion(ahora: t0.add(const Duration(seconds: 3))), isFalse);
      expect(AtajoVolumenSos.registrarPulsacion(ahora: t0.add(const Duration(seconds: 6))), isFalse);
    });
  });
}
