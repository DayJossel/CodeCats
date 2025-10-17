// lib/device/location_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Pide permisos y habilita el servicio si está apagado.
  static Future<void> _ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // No forzamos settings aquí; avisamos por log y seguimos (usaremos fallback)
      debugPrint('[LOC] El servicio de ubicación está desactivado.');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      // El usuario denegó permanentemente. Puedes abrir ajustes si quieres:
      // await Geolocator.openAppSettings();
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
  static Future<Position> getCurrentPosition({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    await _ensurePermission();

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeout,
      );
      return pos;
    } on TimeoutException catch (_) {
      debugPrint('[LOC] Timeout getCurrentPosition, probando lastKnown...');
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      rethrow;
    } catch (e) {
      debugPrint('[LOC] Error getCurrentPosition ($e), probando lastKnown...');
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      rethrow;
    }
  }

  static String mapsUrlFrom(double lat, double lng) =>
      'https://maps.google.com/?q=$lat,$lng';
}
