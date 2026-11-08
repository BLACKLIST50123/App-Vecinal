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

  group('Puntaje de confianza', () {
    final hoy = DateTime.now().toIso8601String();
    final viejo = DateTime.now().subtract(const Duration(days: 200)).toIso8601String();
    Map<String, dynamic> vb(String? sector, {bool verificado = true, String? fecha}) =>
        {'autor_sector': sector, 'autor_verificado': verificado, 'motivos': <String>[], 'created_at': fecha ?? hoy};

    test('verificado de tu zona pesa más; lo antiguo vale la mitad', () {
      final s = Servicio.fromMap(_servicio([
        vb('Villa María'), // 1 + 0,5
        vb('Bellamar'), // 1
        vb(null, verificado: false), // 0,5
        vb('Villa María', fecha: viejo), // (1 + 0,5) / 2
      ]));
      expect(s.puntaje('Villa María'), closeTo(1.5 + 1 + 0.5 + 0.75, 0.001));
      expect(s.recientes, 3);
    });

    test('niveles: barrio, muy recomendado, recomendado y nuevo', () {
      expect(Servicio.fromMap(_servicio([vb('A'), vb('A'), vb('A')], sector: 'A')).nivel('A'), NivelConfianza.barrio);
      expect(Servicio.fromMap(_servicio([vb('B'), vb('B'), vb('B')])).nivel('A'), NivelConfianza.muy);
      expect(Servicio.fromMap(_servicio([vb('B')])).nivel('A'), NivelConfianza.recomendado);
      expect(Servicio.fromMap(_servicio([])).nivel('A'), NivelConfianza.nuevo);
    });

    test('el más recomendado por tipo: solo con competencia y sin empate', () {
      Servicio sv(String id, int n, {String cat = 'gasfiteria'}) =>
          Servicio.fromMap({..._servicio([for (var i = 0; i < n; i++) vb('X')]), 'id': id, 'categoria': cat});
      final ids = masRecomendadosPorTipo([sv('a', 4), sv('b', 2), sv('c', 5, cat: 'clases'), sv('d', 1, cat: 'pan')], 'X');
      expect(ids, {'a'}); // clases y pan tienen un solo servicio
      expect(masRecomendadosPorTipo([sv('a', 2), sv('b', 2)], 'X'), isEmpty); // empate
    });
  });

  group('"No me fue bien" (privado)', () {
    Map<String, dynamic> vb(String sector) =>
        {'autor_sector': sector, 'autor_verificado': true, 'motivos': <String>[], 'created_at': DateTime.now().toIso8601String()};
    final cuatro = Servicio.fromMap(_servicio([vb('A'), vb('A'), vb('A'), vb('A')], sector: 'A'));

    test('cada queja resta 1 al puntaje', () {
      expect(cuatro.puntaje('A', quejas: 2), closeTo(cuatro.puntaje('A') - 2, 0.001));
    });

    test('con 3 quejas pierde el sello y el "Muy recomendado"', () {
      expect(cuatro.nivel('A'), NivelConfianza.barrio);
      expect(cuatro.nivel('A', quejas: 3), NivelConfianza.recomendado);
    });

    test('con 3 quejas no puede ser N.º 1', () {
      Servicio sv(String id, int n) =>
          Servicio.fromMap({..._servicio([for (var i = 0; i < n; i++) vb('X')]), 'id': id});
      final lista = [sv('a', 6), sv('b', 2)];
      expect(masRecomendadosPorTipo(lista, 'X'), {'a'});
      expect(masRecomendadosPorTipo(lista, 'X', quejas: {'a': 3}), isEmpty);
    });
  });
}
