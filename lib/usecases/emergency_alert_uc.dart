import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/session_repository.dart';
import '../data/api_service.dart';
import '../device/location_service.dart';
import '../device/sms_service.dart';

class EmergencyAlertResult {
  final int? historialId;
  final List<int> fallidos;
  EmergencyAlertResult({required this.historialId, required this.fallidos});
}

class EmergencyAlertUC {
  static Future<EmergencyAlertResult> trigger({
    String? mensajeLibre,
    List<int>? soloContactoIds,
  }) async {
    // 1) Traer contactos del backend (del corredor en sesión)
    final contactos = await ApiService.getContactos(); // [{contacto_id,telefono,...}]
    if (contactos.isEmpty) {
      throw Exception('No tienes contactos de confianza. Agrega al menos uno.');
    }

    final selected = (soloContactoIds == null || soloContactoIds.isEmpty)
        ? contactos
        : contactos.where((c) => soloContactoIds.contains(c['contacto_id'] as int)).toList();

    if (selected.isEmpty) {
      throw Exception('La selección de contactos quedó vacía.');
    }

    // 2) Permisos para SMS + TELÉFONO
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

    // 4) Mensaje EXACTO del SRS (con fallback si no hay GPS)
    final nombre = await SessionRepository.nombre() ?? 'Corredor';
    final cid = await SessionRepository.corredorId() ?? 0;

    String _corredorDisplayId(int id, {String prefix = 'CHTA-', int pad = 3}) {
      return '$prefix${id.toString().padLeft(pad, '0')}';
    }

    final idVisible = _corredorDisplayId(cid);
    final ubicacionLinea = (lat != null && lng != null)
        ? 'Última ubicación: https://maps.google.com/?q=$lat,$lng'
        : 'Última ubicación: no disponible';

    final mensajePorDefecto = '''
🚨 ALERTA CHITA 🚨
Soy $nombre
Necesito ayuda urgente.
Ultima ubicación registrada:
$ubicacionLinea
Activado desde la app CHITA
'''.trim();

    final mensaje = (mensajeLibre?.trim().isNotEmpty ?? false)
        ? mensajeLibre!.trim()
        : mensajePorDefecto;

    // 5) Si hay internet, registramos la sesión de alerta (Historial)
    final isOnline = await _isOnline();
    int? historialId;
    final ids = selected.map<int>((c) => c['contacto_id'] as int).toList();

    if (isOnline) {
      try {
        final det = await ApiService.activarAlerta(
          mensaje: mensaje,
          lat: (lat ?? 0),
          lng: (lng ?? 0),
          contactoIds: ids,
        );
        historialId = det['historial_id'] as int?;
      } catch (_) {
        // no bloqueamos si el backend falló; seguimos con SMS
      }
    }

    // 6) NORMALIZACIÓN MX a E.164 (AQUÍ ESTÁ) + ENVÍO DE SMS (AQUÍ ESTÁ EL BUCLE)
    String _normalizeMx(String tel) {
      // Quita espacios, guiones y paréntesis
      final t = tel.replaceAll(RegExp(r'[^\d+]'), '');
      if (t.startsWith('+')) return t;                 // ya en internacional
      if (t.length == 10) return '+52$t';              // 10 dígitos locales -> +52
      if (t.length == 12 && t.startsWith('52')) return '+$t'; // 52xxxxxxxxxxxx -> +52...
      return t; // lo que venga si no coincide con los casos comunes
    }

    final fallidos = <int>[];

    // ⬇⬇⬇⬇⬇ ESTE ES EL BUCLE QUE ENVÍA LOS SMS ⬇⬇⬇⬇⬇
    for (final c in selected) {
      final raw = (c['telefono'] as String).trim();
      final tel = _normalizeMx(raw);
      try {
        await SmsService.send(to: tel, message: mensaje);
      } catch (_) {
        fallidos.add(c['contacto_id'] as int);
      }
    }
    // ⬆⬆⬆⬆⬆ FIN DEL BUCLE DE ENVÍO DE SMS ⬆⬆⬆⬆⬆

    // 7) Si hay internet y tenemos historial, registramos envíos OK
    if (isOnline && historialId != null) {
      final enviadosOk = ids.where((id) => !fallidos.contains(id)).toList();
      if (enviadosOk.isNotEmpty) {
        try {
          await ApiService.registrarEnvios(historialId: historialId!, contactoIds: enviadosOk);
        } catch (_) {
          // no bloqueamos UX si el backend falla aquí
        }
      }
    }

    return EmergencyAlertResult(historialId: historialId, fallidos: fallidos);
  }

  static Future<bool> _isOnline() async {
    final c = await Connectivity().checkConnectivity();
    return c != ConnectivityResult.none;
  }
}
