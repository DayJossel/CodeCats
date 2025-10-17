import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/session_repository.dart';

class ApiService {
  // ⚠️ Cambia por tu URL real
  static const String baseUrl = 'http://157.137.187.110:8000';

  static Future<Map<String, String>> _authHeaders() async {
    final cid = await SessionRepository.corredorId();
    final pwd = await SessionRepository.contrasenia();
    return {
      'Content-Type': 'application/json',
      if (cid != null) 'X-Corredor-Id': '$cid',
      if (pwd != null) 'X-Contrasenia': pwd,
    };
  }

  // GET /contactos
  static Future<List<Map<String, dynamic>>> getContactos() async {
    final headers = await _authHeaders();
    final url = Uri.parse('$baseUrl/contactos');
    final resp = await http.get(url, headers: headers);
    if (resp.statusCode == 200) {
      final list = jsonDecode(resp.body) as List;
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('No se pudieron obtener contactos (${resp.statusCode}).');
  }

  // POST /alertas/activar
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
    final resp = await http.post(url, headers: headers, body: body);
    if (resp.statusCode == 201 || resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Fallo al activar alerta (${resp.statusCode}).');
  }

  // POST /alertas/enviar
  static Future<void> registrarEnvios({
    required int historialId,
    required List<int> contactoIds,
  }) async {
    final headers = await _authHeaders();
    final url = Uri.parse('$baseUrl/alertas/enviar');
    final body = jsonEncode({
      'historial_id': historialId,
      'contacto_ids': contactoIds,
    });
    final resp = await http.post(url, headers: headers, body: body);
    if (resp.statusCode != 200) {
      throw Exception('Fallo al registrar envíos (${resp.statusCode}).');
    }
  }

  /// POST /corredores/login
  static Future<Map<String, dynamic>> login({
    required String correo,
    required String contrasenia,
  }) async {
    final url = Uri.parse('$baseUrl/corredores/login');
    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'correo': correo,
        'contrasenia': contrasenia,
      }),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Login falló (${resp.statusCode}).');
  }
}

