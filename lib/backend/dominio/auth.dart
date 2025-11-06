// lib/backend/dominio/auth.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/session_repository.dart';
import '../data/api_service.dart';

class AuthResult {
  final int corredorId;
  final String nombre;
  final String correo;
  const AuthResult({required this.corredorId, required this.nombre, required this.correo});
}

class AuthUC {
  static Uri _u(String path) => Uri.parse('${ServicioApi.baseUrl}$path');

  /// Inicia sesión, guarda la sesión y devuelve info básica del corredor
  static Future<AuthResult> iniciarSesion({
    required String correo,
    required String contrasenia,
  }) async {
    // Usa tu ServicioApi central (ya lo llamabas desde la vista)
    final data = await ServicioApi.iniciarSesion(correo: correo, contrasenia: contrasenia);

    final corredorId = (data['corredor_id'] as num?)?.toInt() ?? (data['id'] as num?)?.toInt();
    final nombre = (data['nombre'] as String?)?.trim() ?? '';
    if (corredorId == null) {
      throw Exception('Credenciales incorrectas');
    }

    await RepositorioSesion.guardarLogin(
      corredorId: corredorId,
      contrasenia: contrasenia,
      nombre: nombre,
      correo: correo,
    );

    return AuthResult(corredorId: corredorId, nombre: nombre, correo: correo);
  }

  /// Crea cuenta en /corredores y retorna el nombre creado (o lanza)
  static Future<String> registrar({
    required String nombre,
    required String correo,
    required String contrasenia,
    required String telefono,
  }) async {
    final resp = await http.post(
      _u('/corredores'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nombre': nombre,
        'correo': correo,
        'contrasenia': contrasenia,
        'telefono': telefono,
      }),
    );

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      return (j['nombre'] as String?)?.trim() ?? nombre;
    }

    // Intenta extraer detalle de error amigable del backend
    try {
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final detalle = (j['detail'] ?? j['message'] ?? 'No se pudo registrar').toString();
      throw Exception('Error (${resp.statusCode}): $detalle');
    } catch (_) {
      throw Exception('Error (${resp.statusCode}) al registrar la cuenta');
    }
  }

  static Future<bool> tieneSesion() async {
    final id = await RepositorioSesion.obtenerCorredorId();
    final pwd = await RepositorioSesion.obtenerContrasenia();
    return id != null && pwd != null && pwd.isNotEmpty;
  }

  static Future<void> cerrarSesion() => RepositorioSesion.limpiar();
}
