// lib/backend/dominio/estadistica.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/session_repository.dart';
import '../data/api_service.dart';
import 'modelos/estadistica.dart';
import 'calendario.dart';                 // para cargar carreras locales
import 'modelos/carrera.dart';            // EstadoCarrera

class EstadisticaUC {
  static Uri _u(String path, Map<String, String> q) {
    final base = ServicioApi.baseUrl; // ej. http://157.137.187.110:8000
    return Uri.parse('$base$path').replace(queryParameters: q);
  }

  static Future<Map<String, String>?> _headersOrNull() async {
    final cid = await RepositorioSesion.obtenerCorredorId();
    final pwd = await RepositorioSesion.obtenerContrasenia();
    if (cid == null || pwd == null || pwd.isEmpty) return null;
    return {
      'X-Corredor-Id': cid.toString(),
      'X-Contrasenia': pwd,
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  /// Para la UI: saber si habilitamos el botón de objetivo.
  static Future<bool> tieneSesion() async {
    final h = await _headersOrNull();
    return h != null;
  }

  /// Carga estadísticas: intenta servidor; si falla, calcula localmente (sin objetivo).
  static Future<EstadisticaMensual> cargar({required int year, required int month}) async {
    final headers = await _headersOrNull();

    // 1) Intento servidor (solo si hay sesión)
    if (headers != null) {
      try {
        final uri = _u('/estadistica/mensual', {'year': '$year', 'month': '$month'});
        final resp = await http.get(uri, headers: headers);
        if (resp.statusCode == 200) {
          final m = jsonDecode(resp.body) as Map<String, dynamic>;
          return EstadisticaMensual.fromApi(m, year: year, month: month);
        }
      } catch (_) {
        // sigue al respaldo local
      }
    }

    // 2) Respaldo local con carreras del CalendarioUC (sin objetivo)
    final cal = CalendarioUC();
    final carreras = await cal.cargarDesdeDisco();
    int total = 0, hechas = 0, pendientes = 0, noRealizadas = 0;

    for (final c in carreras) {
      final d = c.fechaHora;
      if (d.year == year && d.month == month) {
        total++;
        switch (c.estado) {
          case EstadoCarrera.hecha:
            hechas++; break;
          case EstadoCarrera.noRealizada:
            noRealizadas++; break;
          case EstadoCarrera.pendiente:
          default:
            pendientes++; break;
        }
      }
    }

    return EstadisticaMensual(
      year: year,
      month: month,
      objetivo: null,
      total: total,
      hechas: hechas,
      pendientes: pendientes,
      noRealizadas: noRealizadas,
      cumpleObjetivo: null,
      fromLocal: true,
    );
  }

  /// Define/actualiza el objetivo mensual (requiere sesión); relanza si no hay sesión.
  static Future<void> definirObjetivo({required int year, required int month, required int objetivo}) async {
    final headers = await _headersOrNull();
    if (headers == null) {
      throw Exception('No hay sesión cargada.');
    }
    final uri = _u('/objetivos/mensual', {'year': '$year', 'month': '$month'});
    final resp = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'objetivo': objetivo}),
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Error al guardar objetivo (HTTP ${resp.statusCode}).');
    }
  }
}
