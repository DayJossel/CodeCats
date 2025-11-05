import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/session_repository.dart';

class ExcepcionApiHttp implements Exception {
  final String mensaje;
  final int? codigoEstado;
  ExcepcionApiHttp(this.mensaje, {this.codigoEstado});
  @override
  String toString() => 'ExcepcionApiHttp($codigoEstado): $mensaje';
}

class ServicioApi {
  static const String baseUrl = 'http://157.137.187.110:8000';

  static Future<Map<String, String>> _encabezadosAutenticacion() async {
    final cid = await RepositorioSesion.obtenerCorredorId();
    final pwd = await RepositorioSesion.obtenerContrasenia();
    if (cid == null || pwd == null || pwd.isEmpty) {
      throw ExcepcionApiHttp('No hay credenciales de sesión.');
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Corredor-Id': '$cid',
      'X-Contrasenia': pwd,
    };
  }

  // ---------- Contactos ----------
  static Future<List<Map<String, dynamic>>> obtenerContactos() async {
    final headers = await _encabezadosAutenticacion();
    final url = Uri.parse('$baseUrl/contactos');

    final resp = await http.get(url, headers: headers)
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data is List) return data.cast<Map<String, dynamic>>();
      throw ExcepcionApiHttp('Formato inesperado de /contactos');
    }
    _lanzarHttp(resp);
  }

  /// Alias temporal para compatibilidad con código existente.
  static Future<List<Map<String, dynamic>>> getContactos() =>
      obtenerContactos();

  // ---------- Alertas ----------
  static Future<Map<String, dynamic>> activarAlerta({
    required String mensaje,
    required double lat,
    required double lng,
    required List<int> contactoIds,
  }) async {
    final headers = await _encabezadosAutenticacion();
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
      throw ExcepcionApiHttp('Formato inesperado de /alertas/activar');
    }
    _lanzarHttp(resp);
  }

  // ---------- Corredores (login) ----------
  static Future<Map<String, dynamic>> iniciarSesion({
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
      throw ExcepcionApiHttp('Formato inesperado de /corredores/login');
    }
    _lanzarHttp(resp);
  }

  /// Alias temporal para compatibilidad.
  static Future<Map<String, dynamic>> login({
    required String correo,
    required String contrasenia,
  }) =>
      iniciarSesion(correo: correo, contrasenia: contrasenia);

  // ---------- Historial ----------
  static Future<List<Map<String, dynamic>>> listarHistorial() async {
    final headers = await _encabezadosAutenticacion();
    final url = Uri.parse('$baseUrl/alertas/historial');

    final resp = await http.get(url, headers: headers)
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data is List) return data.cast<Map<String, dynamic>>();
      throw ExcepcionApiHttp('Formato inesperado de /alertas/historial');
    }
    _lanzarHttp(resp);
  }

  // ---------- Helper ----------
  static Never _lanzarHttp(http.Response resp) {
    try {
      final j = jsonDecode(resp.body);
      throw ExcepcionApiHttp(j.toString(), codigoEstado: resp.statusCode); // ← fix aquí
    } catch (_) {
      throw ExcepcionApiHttp(
        'HTTP ${resp.statusCode}: ${resp.body}',
        codigoEstado: resp.statusCode, // ← y aquí
      );
    }
  }
}