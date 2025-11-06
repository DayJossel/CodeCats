// lib/backend/dominio/contactos.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/session_repository.dart';
import '../data/api_service.dart';
import 'modelos/contacto.dart';

class ContactosUC {
  static String get _baseUrl => ServicioApi.baseUrl;

  static Map<String, String> _headersAuth({
    required int corredorId,
    required String contrasenia,
  }) =>
      {
        'X-Corredor-Id': '$corredorId',
        'X-Contrasenia': contrasenia,
        'Content-Type': 'application/json',
      };

  /// Carga credenciales desde RepositorioSesion.
  static Future<(int corredorId, String contrasenia)> _cred() async {
    final cid = await RepositorioSesion.obtenerCorredorId();
    final pwd = await RepositorioSesion.obtenerContrasenia();
    if (cid == null || pwd == null || pwd.isEmpty) {
      throw Exception('No hay sesión. Inicia sesión nuevamente.');
    }
    return (cid, pwd);
  }

  // ---------- Listar ----------
  static Future<List<Contacto>> listar({
    int? corredorId,
    String? contrasenia,
  }) async {
    final creds = (corredorId != null && contrasenia != null)
        ? (corredorId, contrasenia)
        : await _cred();

    final resp = await http.get(
      Uri.parse('$_baseUrl/contactos'),
      headers: _headersAuth(corredorId: creds.$1, contrasenia: creds.$2),
    );

    if (resp.statusCode != 200) {
      throw Exception('Error al obtener contactos (${resp.statusCode}).');
    }

    final List data = jsonDecode(resp.body) as List;
    return data.map((e) => Contacto.fromApi(e as Map<String, dynamic>)).toList();
  }

  // ---------- Crear ----------
  static Future<Contacto> crear({
    required String nombre,
    required String telefono10,
    String relacion = 'N/A',
    int? corredorId,
    String? contrasenia,
  }) async {
    final creds = (corredorId != null && contrasenia != null)
        ? (corredorId, contrasenia)
        : await _cred();

    final body = jsonEncode({
      'nombre': nombre,
      'telefono': telefono10,
      'relacion': relacion,
    });

    final resp = await http.post(
      Uri.parse('$_baseUrl/contactos'),
      headers: _headersAuth(corredorId: creds.$1, contrasenia: creds.$2),
      body: body,
    );

    if (resp.statusCode != 201 && resp.statusCode != 200) {
      throw Exception('Error al crear contacto (${resp.statusCode}): ${resp.body}');
    }

    return Contacto.fromApi(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  // ---------- Actualizar ----------
  static Future<Contacto> actualizar({
    required int contactoId,
    required String nombre,
    required String telefono10,
    String relacion = 'N/A',
    int? corredorId,
    String? contrasenia,
  }) async {
    final creds = (corredorId != null && contrasenia != null)
        ? (corredorId, contrasenia)
        : await _cred();

    final body = jsonEncode({
      'nombre': nombre,
      'telefono': telefono10,
      'relacion': relacion,
    });

    final resp = await http.put(
      Uri.parse('$_baseUrl/contactos/$contactoId'),
      headers: _headersAuth(corredorId: creds.$1, contrasenia: creds.$2),
      body: body,
    );

    if (resp.statusCode != 200) {
      throw Exception('Error al actualizar contacto (${resp.statusCode}): ${resp.body}');
    }

    return Contacto.fromApi(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  // ---------- Eliminar ----------
  static Future<void> eliminar({
    required int contactoId,
    int? corredorId,
    String? contrasenia,
  }) async {
    final creds = (corredorId != null && contrasenia != null)
        ? (corredorId, contrasenia)
        : await _cred();

    final resp = await http.delete(
      Uri.parse('$_baseUrl/contactos/$contactoId'),
      headers: _headersAuth(corredorId: creds.$1, contrasenia: creds.$2),
    );

    if (resp.statusCode != 200) {
      throw Exception('Error al eliminar contacto (${resp.statusCode}): ${resp.body}');
    }
  }

  // ---------- Utilidad de normalización ----------
  /// Deja el teléfono en 10 dígitos MX (quita +52 / 52 / 521 y no dígitos).
  static String normalizarTelefonoMx10(String raw) {
    String digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 13 && digits.startsWith('521')) digits = digits.substring(3);
    if (digits.length == 12 && digits.startsWith('52')) digits = digits.substring(2);
    return digits;
  }
}