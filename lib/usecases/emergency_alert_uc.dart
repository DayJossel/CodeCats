import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/session_repository.dart';
import '../data/api_service.dart';
import '../device/location_service.dart';
import '../device/sms_service.dart';
import '../core/app_events.dart';

class EmergencyAlertResult {
  final int? historialId;
  final List<int> fallidos;
  const EmergencyAlertResult({
    required this.historialId,
    required this.fallidos,
  });
}

class EmergencyAlertUC {
  /// CU-1:
  /// 1) Obtener contactos (o filtrar por ids)
  /// 2) Permisos SMS/Teléfono
  /// 3) Ubicación (best-effort)
  /// 4) Mensaje (formato SRS)
  /// 5) (si hay internet) POST /alertas/activar
  /// 6) Enviar SMS a cada contacto
  static Future<EmergencyAlertResult> trigger({
    String? mensajeLibre,
    List<int>? soloContactoIds,
  }) async {
    // 1) Contactos
    final contactos = await ApiService.getContactos(); // [{contacto_id, telefono, ...}]
    if (contactos.isEmpty) {
      throw Exception('No tienes contactos de confianza. Agrega al menos uno.');
    }

    final seleccion = (soloContactoIds == null || soloContactoIds.isEmpty)
        ? contactos
        : contactos.where((c) {
            final id = (c['contacto_id'] as num).toInt();
            return soloContactoIds.contains(id);
          }).toList();

    if (seleccion.isEmpty) {
      throw Exception('La selección de contactos quedó vacía.');
    }

    // 2) Permisos SMS/Teléfono
    await SmsService.ensureSmsAndPhonePermissions();

    // 3) Ubicación (best-effort)
    double? lat, lng;
    try {
      final pos = await LocationService.getCurrentPosition();
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (e) {
      debugPrint('[ALERTA] Ubicación no disponible: $e');
    }

    // 4) Mensaje (según SRS)
    final nombre = await SessionRepository.nombre() ?? 'Corredor';
    final String urlMapa = (lat != null && lng != null)
        ? LocationService.mapsUrlFrom(lat, lng)
        : 'no disponible';

    final mensajePorDefecto = '''
🚨 ALERTA CHITA 🚨
Soy $nombre
Necesito ayuda urgente.
Última ubicación registrada:
$urlMapa
Activado desde la app CHITA.
'''.trim();

    final mensaje = (mensajeLibre != null && mensajeLibre.trim().isNotEmpty)
        ? mensajeLibre.trim()
        : mensajePorDefecto;

    // 5) Guardar historial si hay internet
    final online = await _isOnline();
    int? historialId;
    final ids = seleccion.map<int>((c) => (c['contacto_id'] as num).toInt()).toList();

    if (online) {
      try {
        final res = await ApiService.activarAlerta(
          mensaje: mensaje,
          lat: (lat ?? 0),
          lng: (lng ?? 0),
          contactoIds: ids,
        );
        historialId = (res['historial_id'] as num?)?.toInt();
        debugPrint('[ALERTA] Historial creado: $historialId');
        if (historialId != null) {
          AppEvents.bumpAlertHistory();
        }
      } catch (e) {
        debugPrint('[ALERTA] activarAlerta falló: $e (continuo con SMS)');
      }
    } else {
      debugPrint('[ALERTA] Sin internet - guardado pendiente (solo SMS).');
    }

    // 6) Envío de SMS (flexible para MX)
    final fallidos = <int>[];
    for (final c in seleccion) {
      final telRaw = (c['telefono'] as String?)?.trim() ?? '';
      final id = (c['contacto_id'] as num).toInt();

      if (telRaw.isEmpty) {
        fallidos.add(id);
        continue;
      }

      try {
        debugPrint('[ALERTA] Enviando SMS a contacto_id=$id tel="$telRaw"');
        await SmsService.sendFlexibleMx(rawPhone: telRaw, message: mensaje);
      } catch (e) {
        debugPrint('[ALERTA] Error enviando a contacto_id=$id: $e');
        fallidos.add(id);
      }
    }

    return EmergencyAlertResult(historialId: historialId, fallidos: fallidos);
  }

  static Future<bool> _isOnline() async {
    try {
      final c = await Connectivity().checkConnectivity();
      return c != ConnectivityResult.none;
    } catch (_) {
      return false;
    }
  }
}