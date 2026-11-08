import 'package:app_vecinal/config.dart';
import 'package:app_vecinal/features/inicio/necesidad.dart';
import 'package:app_vecinal/features/inicio/recomendados.dart';
import 'package:app_vecinal/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DestinoNecesidad a(String t) => interpretarNecesidad(t).destino;

  test('servicios y productos van a lo recomendado cerca', () {
    expect(interpretarNecesidad('Necesito un gasfitero').categoria, 'gasfiteria');
    expect(a('Necesito un gasfitero'), DestinoNecesidad.servicio);
    expect(a('Quiero pan'), DestinoNecesidad.servicio);
    expect(a('Clases de inglés para mi hijo'), DestinoNecesidad.servicio);
  });

  test('pedir prestado o una mano va a Solidaridad', () {
    expect(a('Que me presten una escalera'), DestinoNecesidad.solidaridad);
    expect(interpretarNecesidad('Que me presten una escalera').categoria, 'herramientas');
    expect(a('Necesito que me lleven al hospital'), DestinoNecesidad.solidaridad);
  });

  test('preguntas de recomendación van al foro', () {
    expect(a('¿Alguien conoce un buen profesor?'), DestinoNecesidad.foro);
    expect(a('Me recomiendan una costurera'), DestinoNecesidad.foro);
  });

  test('una emergencia siempre gana', () {
    expect(a('Hay un incendio en mi cuadra'), DestinoNecesidad.emergencia);
    expect(a('Hay un herido, alguien sabe primeros auxilios'), DestinoNecesidad.emergencia);
  });

  test('si no se entiende, se busca en servicios', () {
    expect(a('xyz'), DestinoNecesidad.buscar);
  });

  test('lo más recomendado: primero Vistos Buenos, a igual confianza el más cerca', () {
    const ref = Punto(-9.08, -78.58);
    final lista = rankingRecomendados([
      Servicio(id: 'lejos', categoria: 'gasfiteria', titulo: 'A', vistosBuenos: 2, lat: -9.10, lng: -78.58),
      Servicio(id: 'top', categoria: 'gasfiteria', titulo: 'B', vistosBuenos: 9, lat: -9.081, lng: -78.58),
      Servicio(id: 'cerca', categoria: 'gasfiteria', titulo: 'C', vistosBuenos: 2, lat: -9.0805, lng: -78.58),
      Servicio(id: 'pan', categoria: 'panaderia', titulo: 'D', vistosBuenos: 20, lat: -9.08, lng: -78.58),
      Servicio(id: 'emerg', categoria: 'gasfiteria', titulo: 'E', vistosBuenos: 50, esEmergencia: true),
    ], ref, categoria: 'gasfiteria');
    expect(lista.map((r) => r.servicio.id).toList(), ['top', 'cerca', 'lejos']);
  });
}
