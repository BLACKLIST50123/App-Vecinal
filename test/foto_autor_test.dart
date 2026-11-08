import 'package:app_vecinal/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la publicación trae la foto de perfil de quien la hizo', () {
    final p = Publicacion.fromMap({
      'id': 'p1',
      'tipo': 'pido',
      'categoria': 'ayuda',
      'titulo': 'Ayuda para cargar',
      'autor': {'foto_url': 'https://ejemplo.com/foto.jpg'},
    });
    expect(p.autorFoto, 'https://ejemplo.com/foto.jpg');
  });

  test('sin foto (o sin la migración) queda en blanco y se usan las iniciales', () {
    final p = Publicacion.fromMap({'id': 'p2', 'tipo': 'pido', 'categoria': 'ayuda', 'titulo': 'Sin foto'});
    expect(p.autorFoto, isNull);
  });
}
