import 'package:app_vecinal/models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _servicio(List<Map<String, dynamic>> vistos, {String sector = 'Villa María'}) => {
      'id': 's1',
      'categoria': 'gasfiteria',
      'titulo': 'Gasfitero a domicilio',
      'sector': sector,
      'vistos_buenos': vistos,
    };

Map<String, dynamic> _vb(String? sector, {bool verificado = true, List<String> motivos = const []}) =>
    {'autor_sector': sector, 'autor_verificado': verificado, 'motivos': motivos};

void main() {
  test('consulta antigua (solo conteo) sigue funcionando', () {
    final s = Servicio.fromMap(_servicio([{'count': 4}]));
    expect(s.vistosBuenos, 4);
    expect(s.tieneSello('Villa María'), isFalse);
    expect(s.motivosPrincipales(), isEmpty);
  });

  test('sello: 3 vecinos verificados de tu sector', () {
    final s = Servicio.fromMap(_servicio([
      _vb('Villa María'),
      _vb('Villa María'),
      _vb('Villa María'),
      _vb('Bellamar'),
    ]));
    expect(s.vistosBuenos, 4);
    expect(s.recomendacionesDeZona('Villa María'), 3);
    expect(s.tieneSello('Villa María'), isTrue);
    expect(s.tieneSello('Bellamar'), isFalse);
  });

  test('los no verificados no cuentan para el sello', () {
    final s = Servicio.fromMap(_servicio([
      _vb('Villa María'),
      _vb('Villa María'),
      _vb('Villa María', verificado: false),
    ]));
    expect(s.tieneSello('Villa María'), isFalse);
  });

  test('sin sector de quien mira se usa el del servicio', () {
    final s = Servicio.fromMap(_servicio([_vb('Bellamar'), _vb('Bellamar'), _vb('Bellamar')], sector: 'Bellamar'));
    expect(s.tieneSello(null), isTrue);
  });

  test('motivos principales, del más elegido al menos', () {
    final s = Servicio.fromMap(_servicio([
      _vb('A', motivos: ['puntual', 'precio_justo']),
      _vb('A', motivos: ['puntual']),
      _vb('A', motivos: ['amable', 'puntual', 'precio_justo']),
    ]));
    expect(s.motivosPrincipales(), ['puntual', 'precio_justo']);
    expect(textoMotivo('precio_justo'), 'Precio justo');
  });
}
