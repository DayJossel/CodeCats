// lib/backend/dominio/ubicacion_compartida.dart
import '../core/session_repository.dart';
import '../device/location_service.dart';
import '../device/sms_service.dart';
import 'modelos/contacto.dart';

class UbicacionCompartidaUC {
  /// Asegura permisos de SMS/Teléfono (lanza si no se obtienen).
  static Future<void> asegurarPermisosSms() async {
    await ServicioSMS.asegurarPermisosSmsYTelefono();
  }

  /// Envía 1 vez la ubicación actual a la lista de contactos.
  /// Devuelve (ok, fail) con el conteo por contacto.
  static Future<(int ok, int fail)> enviarUbicacionUnaVez({
    required List<Contacto> contactos,
  }) async {
    double? lat, lng;
    try {
      final pos = await ServicioUbicacion.obtenerPosicionActual();
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {
      lat = null;
      lng = null;
    }

    final corredor = await RepositorioSesion.nombre() ?? 'Corredor';
    final urlMapa = (lat != null && lng != null)
        ? ServicioUbicacion.urlMapsDesde(lat, lng)
        : 'no disponible';

    final mensaje = '''
📍 COMPARTIR UBICACIÓN – CHITA
Soy $corredor y estoy compartiendo mi ubicación.
Última ubicación:
$urlMapa
(Enviado automáticamente por CHITA)
'''.trim();

    var ok = 0;
    var fail = 0;
    for (final c in contactos) {
      final tel = c.telefono.trim();
      if (tel.isEmpty) {
        fail++;
        continue;
      }
      try {
        await ServicioSMS.enviarFlexibleMx(rawPhone: tel, message: mensaje);
        ok++;
      } catch (_) {
        fail++;
      }
    }
    return (ok, fail);
  }
}
