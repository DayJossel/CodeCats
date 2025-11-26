// lib/backend/dominio/profile.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/session_repository.dart';
import '../data/api_service.dart';
import 'modelos/corredor.dart';

class ProfileUC {
  static Uri _u(String path) => Uri.parse('${ServicioApi.baseUrl}$path');

  static Future<Map<String, String>> _headersAuth() async {
    final cid = await RepositorioSesion.obtenerCorredorId();
    final pwd = await RepositorioSesion.obtenerContrasenia();
    if (cid == null || pwd == null || pwd.isEmpty) {
      throw Exception('No hay sesión cargada.');
    }
    return {
      'X-Corredor-Id': '$cid',
      'X-Contrasenia': pwd,
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  static Future<bool> tieneSesion() async {
    final cid = await RepositorioSesion.obtenerCorredorId();
    final pwd = await RepositorioSesion.obtenerContrasenia();
    return cid != null && pwd != null && pwd.isNotEmpty;
  }

  static Future<CorredorPerfil> cargarPerfil() async {
    final headers = await _headersAuth();
    final cid = int.parse(headers['X-Corredor-Id']!);
    final resp = await http.get(_u('/corredores/$cid'), headers: headers);
    if (resp.statusCode == 200) {
      return CorredorPerfil.fromApi(
        jsonDecode(resp.body) as Map<String, dynamic>,
      );
    }
    throw Exception('Error al cargar perfil (HTTP ${resp.statusCode}).');
  }

  /// Actualiza los datos del perfil del corredor.
  ///
  /// Se espera que el backend exponga algo como:
  ///   PUT /corredores/{id}
  /// con un body JSON:
  ///   { "nombre": "...", "correo": "...", "telefono": "..." }
  ///
  /// Devuelve el perfil actualizado.
  static Future<CorredorPerfil> actualizarPerfil({
    required String nombre,
    required String correo,
    required String telefono,
  }) async {
    final headers = await _headersAuth();
    final cid = int.parse(headers['X-Corredor-Id']!);

    final body = jsonEncode({
      'nombre': nombre,
      'correo': correo,
      'telefono': telefono,
    });

    final resp = await http.put(
      _u('/corredores/$cid'),
      headers: headers,
      body: body,
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final perfil = CorredorPerfil.fromApi(data);

      // Actualizar caché local de sesión con el nuevo nombre / correo.
      final pwd = await RepositorioSesion.obtenerContrasenia();
      if (pwd != null && pwd.isNotEmpty) {
        await RepositorioSesion.guardarLogin(
          corredorId: perfil.corredorId,
          contrasenia: pwd,
          nombre: perfil.nombre,
          correo: perfil.correo,
        );
      }

      return perfil;
    }

    // Aquí mapeamos el fallo de actualización (flujo 4E del CU-9)
    throw Exception('Error al actualizar perfil (HTTP ${resp.statusCode}).');
  }

  static Future<void> eliminarCuenta() async {
    final headers = await _headersAuth();
    final cid = int.parse(headers['X-Corredor-Id']!);
    final resp = await http.delete(_u('/corredores/$cid'), headers: headers);
    if (resp.statusCode != 200) {
      throw Exception('Error al eliminar cuenta (HTTP ${resp.statusCode}).');
    }
  }

  static Future<void> cerrarSesion() async {
    await RepositorioSesion.limpiar();
  }
}