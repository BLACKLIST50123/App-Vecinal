import 'package:geolocator/geolocator.dart';

import '../config.dart';

class Ubicacion {
  /// Igual que [gps], pero sin mostrar el diálogo de permiso: solo lee la
  /// ubicación si el vecino ya la autorizó antes (para usar al abrir la app).
  static Future<Punto?> gpsSiHayPermiso() async {
    try {
      final permiso = await Geolocator.checkPermission();
      if (permiso != LocationPermission.always && permiso != LocationPermission.whileInUse) return null;
      return await gps();
    } catch (_) {
      return null;
    }
  }

  /// Ubicación GPS actual, o null si no hay permiso / servicio / señal.
  static Future<Punto?> gps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return Punto(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }
}
