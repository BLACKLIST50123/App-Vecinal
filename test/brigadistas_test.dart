import 'package:app_vecinal/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brigadistas', () {
    test('estados: invitado hasta que acepta', () {
      final b = Brigadista.fromMap({'vecino_id': 'v1', 'sector': 'Bellamar', 'especialidad': 'rescate', 'estado': 'invitado'});
      expect(b.invitado, isTrue);
      expect(b.activo, isFalse);
      expect(b.especialidadNombre, 'Rescate');
    });

    test('especialidad desconocida cae en Apoyo general', () {
      expect(especialidadBrigadista('otra').$2, 'Apoyo general');
    });

    test('se guarda y se recupera igual (para usarlo sin internet)', () {
      final b = Brigadista(vecinoId: 'v1', sector: 'Bellamar', especialidad: 'evacuacion', estado: 'activo', nombre: 'Pedro');
      final c = Brigadista.fromMap(b.toJson());
      expect((c.vecinoId, c.sector, c.especialidad, c.estado, c.nombre), ('v1', 'Bellamar', 'evacuacion', 'activo', 'Pedro'));
    });
  });

  group('Canales del sector', () {
    CanalSector canal(String tipo, String valor) => CanalSector(sector: 'Bellamar', tipo: tipo, etiqueta: 'X', valor: valor);

    test('WhatsApp y Telegram se abren como enlace', () {
      expect(canal('whatsapp', 'https://chat.whatsapp.com/abc').enlace.toString(), 'https://chat.whatsapp.com/abc');
      expect(canal('telegram', 'https://t.me/barrio').enlace?.host, 't.me');
    });

    test('el teléfono abre la llamada', () {
      expect(canal('telefono', '987 654 321').enlace.toString(), 'tel:987654321');
    });

    test('una reunión es solo texto', () {
      expect(canal('reunion', 'Sábados 6 pm, local comunal').enlace, isNull);
    });
  });
}
