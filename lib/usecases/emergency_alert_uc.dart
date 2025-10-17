// lib/usecases/emergency_alert_uc.dart
import 'package:flutter/foundation.dart';                 // <- para debugPrint
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/session_repository.dart';
import '../data/api_service.dart';
import '../device/location_service.dart';
import '../device/sms_service.dart';

class EmergencyAlertResult {
  final int? historialId;
  final List<int> fallidos;
  const EmergencyAlertResult({
    required this.historialId,
    required this.fallidos,
  });
}

class EmergencyAlertUC {
  /// Dispara la alerta:
  /// 1) Obtiene contactos
  /// 2) Pide permisos SMS/Teléfono
  /// 3) Toma ubicación (best-effort)
  /// 4) Arma mensaje (formato SRS)
  /// 5) (si hay internet) POST /alertas/activar
  /// 6) Envía SMS a cada contacto (flex: 10 dígitos, 52..., +52..., fallback a app de SMS)
  /// 7) (si hay internet) POST /alertas/enviar con los que sí salieron
  static Future<EmergencyAlertResult> trigger({
    String? mensajeLibre,
    List<int>? soloContactoIds,
  }) async {
    // 1) Contactos
    final contactos = await ApiService.getContactos(); // [{contacto_id, telefono, ...}]
    if (contactos.isEmpty) {
      throw Exception('No tienes contactos de confianza. Agrega al menos uno.');
    }

    final selected = (soloContactoIds == null || soloContactoIds.isEmpty)
        ? contactos
        : contactos
            .where((c) => soloContactoIds.contains((c['contacto_id'] as num).toInt()))
            .toList();

    if (selected.isEmpty) {
      throw Exception('La selección de contactos quedó vacía.');
    }

    // 2) Permisos SMS/Teléfono (vía plugin + permission_handler)
    await SmsService.ensureSmsAndPhonePermissions();

    // 3) Ubicación (best-effort)
    double? lat, lng;
    try {
      final pos = await LocationService.getCurrentPosition();
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {
      lat = null;
      lng = null;
    }

    // 4) Mensaje EXACTO del SRS
    final nombre = await SessionRepository.nombre() ?? 'Corredor';

final String urlMapa = (lat != null && lng != null)
    ? LocationService.mapsUrlFrom(lat!, lng!)
    : 'no disponible';

final mensajePorDefecto = '''
🚨 ALERTA CHITA 🚨
Soy $nombre
Necesito ayuda urgente.
Última ubicación registrada:
$urlMapa
Activado desde la app CHITA.
'''.trim();

final mensaje = (mensajeLibre?.trim().isNotEmpty ?? false)
    ? mensajeLibre!.trim()
    : mensajePorDefecto;

    // 5) Registrar sesión de alerta si hay internet
    final isOnline = await _isOnline();
    int? historialId;
    final ids = selected.map<int>((c) => (c['contacto_id'] as num).toInt()).toList();

    if (isOnline) {
      try {
        final det = await ApiService.activarAlerta(
          mensaje: mensaje,
          lat: (lat ?? 0),
          lng: (lng ?? 0),
          contactoIds: ids,
        );
        historialId = (det['historial_id'] as num?)?.toInt();
        debugPrint('[ALERTA] Historial creado: $historialId');
      } catch (e) {
        debugPrint('[ALERTA] activarAlerta falló: $e (continuo con SMS)');
      }
    } else {
      debugPrint('[ALERTA] Sin internet - envío solo SMS.');
    }

    // 6) ENVÍO DE SMS (flexible MX) + logs
    final fallidos = <int>[];

    for (final c in selected) {
      final raw = (c['telefono'] as String?)?.trim() ?? '';
      final id = (c['contacto_id'] as num).toInt();

      if (raw.isEmpty) {
        fallidos.add(id);
        continue;
      }

      try {
        debugPrint('[ALERTA] Enviando SMS a contacto_id=$id tel="$raw"');
        await SmsService.sendFlexibleMx(rawPhone: raw, message: mensaje);
      } catch (e) {
        debugPrint('[ALERTA] Error enviando a contacto_id=$id: $e');
        fallidos.add(id);
      }
    }

    // 7) Registrar envíos OK si hay internet e historial
    if (isOnline && historialId != null) {
      final enviadosOk = ids.where((id) => !fallidos.contains(id)).toList();
      if (enviadosOk.isNotEmpty) {
        try {
          await ApiService.registrarEnvios(
            historialId: historialId!,
            contactoIds: enviadosOk,
          );
          debugPrint('[ALERTA] Registrados envíos OK: $enviadosOk');
        } catch (e) {
          debugPrint('[ALERTA] registrarEnvios falló: $e');
        }
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
