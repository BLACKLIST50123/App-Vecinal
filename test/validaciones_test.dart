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

  test('teléfono: rechaza números de un solo dígito repetido', () {
    expect(validarTelefono('999999999'), isNotNull);
  });

  test('nombre: largo máximo y letras repetidas', () {
    expect(validarNombre('a' * 61), isNotNull);
    expect(validarNombre('Juaaaan'), isNotNull);
    expect(validarNombre('Idiota'), isNotNull);
  });

  test('título: obligatorio, con palabras y sin contenido indebido', () {
    expect(validarTitulo('Necesito una escalera'), isNull);
    expect(validarTitulo(''), isNotNull);
    expect(validarTitulo('Hola'), isNotNull);
    expect(validarTitulo('12345 678'), isNotNull);
    expect(validarTitulo('x' * 121), isNotNull);
    expect(validarTitulo('Vendo en www.estafa.com'), isNotNull);
  });

  test('contenido: lenguaje, enlaces, datos privados, mayúsculas y spam', () {
    expect(revisarContenido('Gracias vecino, muy amable'), isNull);
    expect(revisarContenido('eres un idiota'), isNotNull);
    expect(revisarContenido('mira https://bit.ly/abc'), isNotNull);
    expect(revisarContenido('mi tarjeta 4111 1111 1111 1111'), isNotNull);
    expect(revisarContenido('mi DNI es 45678912'), isNotNull);
    expect(revisarContenido('NECESITO AYUDA URGENTE YA'), isNotNull);
    expect(revisarContenido('holaaaaaaaaa'), isNotNull);
    // Palabra entera: "disputa" no es ofensiva.
    expect(revisarContenido('Hubo una disputa por el agua'), isNull);
  });

  test('texto libre: largo máximo', () {
    expect(validarTexto('a b ' * 200), isNotNull);
  });

  test('precio y horario', () {
    expect(validarPrecio('100000'), isNotNull);
    expect(validarHorario(''), isNull);
    expect(validarHorario('Lun a Sáb, 8 am a 6 pm'), isNull);
    expect(validarHorario('x'), isNotNull);
  });

  test('correo', () {
    expect(validarCorreo('rosa@correo.com'), isNull);
    expect(validarCorreo('rosa@correo'), isNotNull);
    expect(validarCorreo('rosa'), isNotNull);
  });

  test('clave con celular: 6 números y no fácil', () {
    expect(validarClave('482915', conCorreo: false), isNull);
    expect(validarClave('12345', conCorreo: false), isNotNull);
    expect(validarClave('123456', conCorreo: false), isNotNull);
    expect(validarClave('111111', conCorreo: false), isNotNull);
    expect(validarClave('654321', conCorreo: false), isNotNull);
    expect(validarClave('654328', conCorreo: false, celular: '987654328'), isNotNull);
  });

  test('contraseña con correo: 8 caracteres con letras y números', () {
    expect(validarClave('vecino2026', conCorreo: true), isNull);
    expect(validarClave('corta1', conCorreo: true), isNotNull);
    expect(validarClave('solamenteletras', conCorreo: true), isNotNull);
  });

  test('rangos', () {
    expect(validarRango(3, min: 1, max: 50), isNull);
    expect(validarRango(0, min: 1, max: 50), isNotNull);
    expect(validarRango(51, min: 1, max: 50), isNotNull);
  });
}
