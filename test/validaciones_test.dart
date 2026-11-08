import 'package:app_vecinal/util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teléfono: 9 dígitos y empieza en 9', () {
    expect(validarTelefono('987654321'), isNull);
    expect(validarTelefono(''), isNull);
    expect(validarTelefono('', obligatorio: true), isNotNull);
    expect(validarTelefono('812345678'), isNotNull);
    expect(validarTelefono('98765432'), isNotNull);
    expect(validarTelefono('98765432a'), isNotNull);
  });

  test('nombre: solo letras', () {
    expect(validarNombre('María José Ñique'), isNull);
    expect(validarNombre("D'Ángelo"), isNull);
    expect(validarNombre('Juan2'), isNotNull);
    expect(validarNombre('J'), isNotNull);
    expect(validarNombre('  '), isNotNull);
  });

  test('texto libre: largo mínimo', () {
    expect(validarTexto('corto'), isNotNull);
    expect(validarTexto(''), isNull);
    expect(validarTexto('', obligatorio: true), isNotNull);
    expect(validarTexto('Necesito una escalera por dos horas'), isNull);
  });

  test('precio: solo números, se guarda con S/', () {
    expect(validarPrecio('30'), isNull);
    expect(validarPrecio(''), isNull);
    expect(validarPrecio('0'), isNotNull);
    expect(validarPrecio('3a'), isNotNull);
    expect(precioGuardado('30'), 'S/ 30');
    expect(precioGuardado(''), isNull);
    expect(precioEditable('Desde S/ 30'), '30');
    expect(precioEditable(null), '');
  });
}
