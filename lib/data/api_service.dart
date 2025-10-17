import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/session_repository.dart';

class ApiHttpException implements Exception {
  final String message;
  final int? statusCode;
  ApiHttpException(this.message, {this.statusCode});
  @override
  String toString() => 'ApiHttpException($statusCode): $message';
}

class ApiService {
  static const String baseUrl = 'http://157.137.187.110:8000';

  /// Headers con credenciales. Falla si no hay sesión.
  static Future<Map<String, String>> _authHeaders() async {
    final cid = await SessionRepository.corredorId();
    final pwd = await SessionRepository.contrasenia();
    if (cid == null || pwd == null || pwd.isEmpty) {
      throw ApiHttpException('No hay credenciales de sesión.');
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Corredor-Id': '$cid',
      'X-Contrasenia': pwd,
    };
  }

  // ---------- Contactos ----------

  /// GET /contactos  ->  List<Map<String,dynamic>>
  static Future<List<Map<String, dynamic>>> getContactos() async {
    final headers = await _authHeaders();
    final url = Uri.parse('$baseUrl/contactos');

    final resp = await http.get(url, headers: headers)
      .timeout(const Duration(seconds: 15));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data is List) return data.cast<Map<String, dynamic>>();
      throw ApiHttpException('Formato inesperado de /contactos');
    }
    _throwHttp(resp);
  }

  // ---------- Alertas ----------

  /// POST /alertas/activar  ->  { historial_id, ... }
  static Future<Map<String, dynamic>> activarAlerta({
    required String mensaje,
    required double lat,
    required double lng,
    required List<int> contactoIds,
  }) async {
    final headers = await _authHeaders();
    final url = Uri.parse('$baseUrl/alertas/activar');

    final body = jsonEncode({
      'mensaje': mensaje,
      'lat': lat,
      'lng': lng,
      'contacto_ids': contactoIds,
    });

    final resp = await http.post(url, headers: headers, body: body)
      .timeout(const Duration(seconds: 20));

    if (resp.statusCode == 201 || resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data is Map<String, dynamic>) return data;
      throw ApiHttpException('Formato inesperado de /alertas/activar');
    }
    _throwHttp(resp);
  }

  // ---------- Corredores (login) ----------

  /// POST /corredores/login  ->  { corredor_id, nombre, correo, ... }
  static Future<Map<String, dynamic>> login({
    required String correo,
    required String contrasenia,
  }) async {
    final url = Uri.parse('$baseUrl/corredores/login');

    final resp = await http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'correo': correo, 'contrasenia': contrasenia}),
    ).timeout(const Duration(seconds: 15));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data is Map<String, dynamic>) return data;
      throw ApiHttpException('Formato inesperado de /corredores/login');
    }
    _throwHttp(resp);
  }

  // ---------- Helpers ----------

  static Never _throwHttp(http.Response resp) {
    try {
      final j = jsonDecode(resp.body);
      throw ApiHttpException(j.toString(), statusCode: resp.statusCode);
    } catch (_) {
      throw ApiHttpException('HTTP ${resp.statusCode}: ${resp.body}',
          statusCode: resp.statusCode);
    }
  }
}
