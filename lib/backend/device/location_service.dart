// lib/device/location_service.dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';

class ServicioUbicacion {
  /// Pide permisos y habilita el servicio si está apagado.
  static Future<void> _asegurarPermiso() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Sin forzar settings; se continúa con fallback si aplica.
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Permiso de ubicación denegado permanentemente. Habilítalo en Ajustes.',
      );
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Permiso de ubicación denegado.');
    }
  }

  /// Intenta obtener la ubicación actual con alta precisión y timeout,
  /// con fallback a la última conocida (si existe).
  static Future<Position> obtenerPosicionActual({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    await _asegurarPermiso();

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeout,
      );
      return pos;
    } on TimeoutException catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      rethrow;
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      rethrow;
    }
  }

  static String urlMapsDesde(double lat, double lng) =>
      'https://maps.google.com/?q=$lat,$lng';
}
