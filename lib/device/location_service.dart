import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  /// Pide permiso y devuelve Position. Lanza Exception con mensaje entendible si falla.
  static Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('GPS desactivado. Actívalo y vuelve a intentar.');
    }

    // Permiso a nivel plugin Geolocator
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        throw Exception('Permiso de ubicación denegado.');
      }
    }
    if (perm == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación denegado permanentemente. Ve a Ajustes.');
    }

    // En Android 12+ algunos fabricantes piden también el de precisión
    final pStatus = await Permission.location.request();
    if (!pStatus.isGranted) {
      throw Exception('Permiso de ubicación no concedido.');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
