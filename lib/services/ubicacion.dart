import 'package:geolocator/geolocator.dart';

import '../config.dart';

class Ubicacion {
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
