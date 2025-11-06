// lib/backend/core/app_boot.dart
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

class AppBoot {
  /// Inicializa servicios de la app (notificaciones, permisos, etc.)
  static Future<void> inicializar() async {
    try {
      await ServicioNotificaciones.instancia.inicializar();
      await ServicioNotificaciones.instancia.solicitarPermisoNotificaciones();
    } catch (e, st) {
      if (kDebugMode) {
        // Evita crashear si el permiso falla; en producción se ignora.
        // Puedes loggear a tu sistema si quieres.
        // print('Boot error: $e\n$st');
      }
    }
  }
}
