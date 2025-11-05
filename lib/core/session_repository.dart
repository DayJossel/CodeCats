import 'package:shared_preferences/shared_preferences.dart';

class RepositorioSesion {
  static const _kCorredorId = 'corredor_id';
  static const _kContrasenia = 'contrasenia';
  static const _kNombre = 'nombre_corredor';
  static const _kCorreo = 'correo_corredor';

  static Future<void> guardarLogin({
    required int corredorId,
    required String contrasenia,
    required String nombre,
    required String correo,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt(_kCorredorId, corredorId);
    await sp.setString(_kContrasenia, contrasenia);
    await sp.setString(_kNombre, nombre);
    await sp.setString(_kCorreo, correo);
  }

  static Future<int?> obtenerCorredorId() async =>
      (await SharedPreferences.getInstance()).getInt(_kCorredorId);

  static Future<String?> obtenerContrasenia() async =>
      (await SharedPreferences.getInstance()).getString(_kContrasenia);

  static Future<String?> nombre() async =>
      (await SharedPreferences.getInstance()).getString(_kNombre);

  static Future<String?> correo() async =>
      (await SharedPreferences.getInstance()).getString(_kCorreo);

  static Future<void> limpiar() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kCorredorId);
    await sp.remove(_kContrasenia);
    await sp.remove(_kNombre);
    await sp.remove(_kCorreo);
  }
}
