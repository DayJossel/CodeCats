// lib/usecases/emergency_alert_uc.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/session_repository.dart';
import '../data/api_service.dart';
import '../device/location_service.dart';
import '../device/sms_service.dart';
import '../core/app_events.dart';

class ResultadoAlertaEmergencia {
  final int? historialId;
  final List<int> fallidos;
  const ResultadoAlertaEmergencia({
    required this.historialId,
    required this.fallidos,
  });
}

class CasoUsoAlertaEmergencia {
  /// CU-1:
  /// 1) Obtener contactos (o filtrar por ids)
  /// 2) Permisos SMS/Teléfono
  /// 3) Ubicación (best-effort)
  /// 4) Mensaje (formato SRS)
  /// 5) (si hay internet) POST /alertas/activar
  /// 6) Enviar SMS a cada contacto
  static Future<ResultadoAlertaEmergencia> activarAlertaEmergencia({
    String? mensajeLibre,
    List<int>? soloContactoIds,
  }) async {
    // 1) Contactos
    final contactos = await ServicioApi.getContactos(); // [{contacto_id, telefono, ...}]
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
    await ServicioSMS.asegurarPermisosSmsYTelefono();

    // 3) Ubicación (best-effort)
    double? lat, lng;
    try {
      final pos = await ServicioUbicacion.obtenerPosicionActual();
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {}

    // 4) Mensaje (según SRS)
    final nombre = await RepositorioSesion.nombre() ?? 'Corredor';
    final String urlMapa = (lat != null && lng != null)
        ? ServicioUbicacion.urlMapsDesde(lat, lng)
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
    final online = await _estaEnLinea();
    int? historialId;
    final ids = seleccion.map<int>((c) => (c['contacto_id'] as num).toInt()).toList();

    if (online) {
      try {
        final res = await ServicioApi.activarAlerta(
          mensaje: mensaje,
          lat: (lat ?? 0),
          lng: (lng ?? 0),
          contactoIds: ids,
        );
        historialId = (res['historial_id'] as num?)?.toInt();
        if (historialId != null) {
          EventosApp.incrementarHistorialAlertas();
        }
      } catch (_) {
        // Continuar con SMS aunque falle el backend.
      }
    } else {
      // Sin internet: continuar con SMS.
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
        await ServicioSMS.enviarFlexibleMx(rawPhone: telRaw, message: mensaje);
      } catch (_) {
        fallidos.add(id);
      }
    }

    return ResultadoAlertaEmergencia(historialId: historialId, fallidos: fallidos);
  }

  static Future<bool> _estaEnLinea() async {
    try {
      final c = await Connectivity().checkConnectivity();
      return c != ConnectivityResult.none;
    } catch (_) {
      return false;
    }
  }
}
