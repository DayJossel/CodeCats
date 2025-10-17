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
    final contactos = await ApiService.getContactos(); // [{contacto_id,telefono,...}]
    if (contactos.isEmpty) throw Exception('No tienes contactos de confianza. Agrega al menos uno.');

    final selected = (soloContactoIds == null || soloContactoIds.isEmpty)
        ? contactos
        : contactos.where((c) => soloContactoIds.contains(c['contacto_id'] as int)).toList();

    if (selected.isEmpty) throw Exception('La selección de contactos quedó vacía.');

    await SmsService.ensureSmsPermission();

    double? lat, lng;
    try {
      final pos = await LocationService.getCurrentPosition();
      lat = pos.latitude; lng = pos.longitude;
    } catch (_) { lat = null; lng = null; }

    // Datos del corredor para el template SRS
    final nombre = await SessionRepository.nombre() ?? 'Corredor';
    final cid = await SessionRepository.corredorId() ?? 0;

    // (Opcional) Si quieres el formato CHTA-023 como en el SRS:
    String corredorDisplayId(int id, {String prefix = 'CHTA-', int pad = 3}) {
      return '$prefix${id.toString().padLeft(pad, '0')}';
    }
    final idVisible = corredorDisplayId(cid); // p.ej. CHTA-023

    // Línea de ubicación para el SRS
    final ubicacionLinea = (lat != null && lng != null)
        ? 'Última ubicación: https://maps.google.com/?q=$lat,$lng'
        : 'Última ubicación: no disponible';

    // MENSAJE EXACTO DEL SRS (si no te pasan uno personalizado)
    final mensajePorDefecto = '''
    🚨 ALERTA CHITA 🚨
    Soy $nombre (ID: $idVisible).
    Necesito ayuda urgente.
    $ubicacionLinea
    '''.trim();

    final mensaje = (mensajeLibre?.trim().isNotEmpty ?? false)
        ? mensajeLibre!.trim()
        : mensajePorDefecto;


    final isOnline = await _isOnline();
    int? historialId;
    final ids = selected.map<int>((c) => c['contacto_id'] as int).toList();

    if (isOnline) {
      try {
        final det = await ApiService.activarAlerta(
          mensaje: mensaje, lat: lat ?? 0, lng: lng ?? 0, contactoIds: ids,
        );
        historialId = det['historial_id'] as int?;
      } catch (_) {/* seguimos con SMS */}
    }

    final fallidos = <int>[];
    for (final c in selected) {
      try {
        await SmsService.send(to: (c['telefono'] as String).trim(), message: mensaje);
      } catch (_) {
        fallidos.add(c['contacto_id'] as int);
      }
    }

    if (isOnline && historialId != null) {
      final enviadosOk = ids.where((id) => !fallidos.contains(id)).toList();
      if (enviadosOk.isNotEmpty) {
        try {
          await ApiService.registrarEnvios(historialId: historialId!, contactoIds: enviadosOk);
        } catch (_) {/* no bloqueamos UX */}
      }
    }

    return EmergencyAlertResult(historialId: historialId, fallidos: fallidos);
  }

  static Future<bool> _isOnline() async {
    final c = await Connectivity().checkConnectivity();
    return c != ConnectivityResult.none;
  }
}