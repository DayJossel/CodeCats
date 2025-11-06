// lib/backend/dominio/espacios.dart
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../core/session_repository.dart';
import '../data/api_service.dart'; // Para usar ServicioApi.baseUrl
import 'modelos/espacio.dart';

class EspaciosUC {
  // ==================== Helpers de auth/base ====================
  static Future<Map<String, String>> _headers() async {
    final cid = await RepositorioSesion.obtenerCorredorId();
    final pwd = await RepositorioSesion.obtenerContrasenia();
    if (cid == null || pwd == null || pwd.isEmpty) {
      throw Exception('Sesión inválida: faltan credenciales.');
    }
    return {
      'X-Corredor-Id': cid.toString(),
      'X-Contrasenia': pwd,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  static Uri _u(String path) => Uri.parse('${ServicioApi.baseUrl}$path');

  // ==================== Parsing/Resolución de coordenadas ====================
  static bool _esUrlProbable(String s) =>
      s.startsWith('http://') || s.startsWith('https://');

  static (String, String)? extraerCoordenadasLocal(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final plain = RegExp(r'^\s*(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)\s*$');
    final mPlain = plain.firstMatch(text);
    if (mPlain != null) return (mPlain.group(1)!, mPlain.group(2)!);

    final geo = RegExp(r'^geo:\s*(-?\d{1,3}(?:\.\d+)?),\s*(-?\d{1,3}(?:\.\d+)?)');
    final mGeo = geo.firstMatch(text);
    if (mGeo != null) return (mGeo.group(1)!, mGeo.group(2)!);

    if (_esUrlProbable(text)) {
      final uri = Uri.tryParse(text);

      final q = uri?.queryParameters['q'];
      if (q != null) {
        final mq = plain.firstMatch(q);
        if (mq != null) return (mq.group(1)!, mq.group(2)!);
      }

      final ll = uri?.queryParameters['ll'];
      if (ll != null) {
        final mll = plain.firstMatch(ll);
        if (mll != null) return (mll.group(1)!, mll.group(2)!);
      }

      final query = uri?.queryParameters['query'];
      if (query != null) {
        final mQuery = plain.firstMatch(query);
        if (mQuery != null) return (mQuery.group(1)!, mQuery.group(2)!);
      }

      final at = RegExp(r'@(-?\d{1,3}(?:\.\d+)?),\s*(-?\d{1,3}(?:\.\d+)?)');
      final mAt = at.firstMatch(text);
      if (mAt != null) return (mAt.group(1)!, mAt.group(2)!);

      final bang = RegExp(r'!3d(-?\d{1,3}(?:\.\d+)?)!4d(-?\d{1,3}(?:\.\d+)?)');
      final mBang = bang.firstMatch(text);
      if (mBang != null) return (mBang.group(1)!, mBang.group(2)!);
    }
    return null;
  }

  static String urlMapsCanonica(String lat, String lng) =>
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  static Future<(String, String)?> resolverCoordenadas(String raw) async {
    final direct = extraerCoordenadasLocal(raw);
    if (direct != null) return direct;
    if (!_esUrlProbable(raw)) return null;

    final client = http.Client();
    try {
      Uri current = Uri.parse(raw);

      for (int i = 0; i < 6; i++) {
        final req = http.Request('GET', current);
        req.followRedirects = false;
        req.headers['User-Agent'] = 'Mozilla/5.0 (Flutter; Dart)';

        final streamed = await client.send(req);
        final status = streamed.statusCode;

        final parsedHere = extraerCoordenadasLocal(current.toString());
        if (parsedHere != null) return parsedHere;

        if (status >= 300 && status < 400) {
          final loc = streamed.headers['location'];
          if (loc == null || loc.isEmpty) break;

          Uri next = Uri.parse(Uri.decodeFull(loc));
          final inner = next.queryParameters['link'];
          if (inner != null && inner.isNotEmpty) {
            next = Uri.parse(Uri.decodeFull(inner));
          }
          current = next;
          continue;
        }

        final body = await streamed.stream.bytesToString();
        final meta = RegExp(
          r"""http-equiv=["']refresh["'][^>]*content=["'][^;]*;\s*url=([^"']+)["']""",
          caseSensitive: false,
        );
        final m = meta.firstMatch(body);
        if (m != null) {
          final redirected = Uri.parse(Uri.decodeFull(m.group(1)!));
          final parsedMeta = extraerCoordenadasLocal(redirected.toString());
          if (parsedMeta != null) return parsedMeta;

          final inner2 = redirected.queryParameters['link'];
          if (inner2 != null && inner2.isNotEmpty) {
            final innerUri = Uri.parse(Uri.decodeFull(inner2));
            final parsedInner = extraerCoordenadasLocal(innerUri.toString());
            if (parsedInner != null) return parsedInner;
            current = innerUri;
            continue;
          }
        }
        break;
      }
    } finally {
      client.close();
    }
    return null;
  }

  // ==================== API: Espacios ====================
  static Future<List<Espacio>> listarEspacios() async {
    final headers = await _headers();
    final resp = await http.get(_u('/espacios'), headers: headers);
    if (resp.statusCode != 200) {
      throw Exception('No se pudo obtener la lista de espacios (HTTP ${resp.statusCode}).');
    }
    final data = jsonDecode(resp.body) as List<dynamic>;
    return data.map((e) => Espacio.fromApi(e as Map<String, dynamic>)).toList();
  }

  /// Reglas:
  /// - Con internet: el link DEBE contener coordenadas (directas o resolviendo redirecciones).
  /// - Sin internet: se acepta tal cual sin validar.
  static Future<Espacio> crearEspacio({
    required String nombre,
    required String enlaceRaw,
  }) async {
    final nombreTrim = nombre.trim();
    final enlaceTrim = enlaceRaw.trim();
    if (nombreTrim.isEmpty) throw Exception('El nombre es obligatorio.');
    if (enlaceTrim.isEmpty) throw Exception('El link es obligatorio.');

    final conn = await Connectivity().checkConnectivity();
    (String, String)? coords;

    if (conn != ConnectivityResult.none) {
      coords = extraerCoordenadasLocal(enlaceTrim);
      if (coords == null && _esUrlProbable(enlaceTrim)) {
        coords = await resolverCoordenadas(enlaceTrim);
      }
      if (coords == null) {
        throw Exception(
          'URL inválida: solo se aceptan enlaces con latitud y longitud (p. ej. "22.77,-102.58" '
          'o un link de Maps que incluya coordenadas).',
        );
      }
    }

    final enlaceParaGuardar =
        (coords != null) ? urlMapsCanonica(coords.$1, coords.$2) : enlaceTrim;

    final headers = await _headers();
    final resp = await http.post(
      _u('/espacios'),
      headers: headers,
      body: jsonEncode({
        'nombreEspacio': nombreTrim,
        'enlaceUbicacion': enlaceParaGuardar,
      }),
    );

    if (resp.statusCode != 200) {
      if (resp.statusCode == 422) {
        throw Exception('Datos inválidos (422). Revisa nombre y enlace.');
      }
      throw Exception('No se pudo crear el espacio (HTTP ${resp.statusCode}).');
    }

    final j = jsonDecode(resp.body) as Map<String, dynamic>;
    return Espacio.fromApi(j);
  }

  // ==================== API: Notas ====================
  static Future<List<NotaEspacio>> listarNotas(int espacioId) async {
    final headers = await _headers();
    final resp = await http.get(_u('/espacios/$espacioId/notas'), headers: headers);
    if (resp.statusCode != 200) {
      throw Exception('No se pudieron cargar notas (HTTP ${resp.statusCode}).');
    }
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((e) => NotaEspacio.fromApi(e as Map<String, dynamic>)).toList();
  }

  static Future<NotaEspacio> crearNota(int espacioId, String contenido) async {
    final headers = await _headers();
    final resp = await http.post(
      _u('/espacios/$espacioId/notas'),
      headers: headers,
      body: jsonEncode({'contenido': contenido}),
    );
    if (resp.statusCode == 201) {
      return NotaEspacio.fromApi(jsonDecode(resp.body) as Map<String, dynamic>);
    } else if (resp.statusCode == 409) {
      throw Exception('Límite de 5 notas alcanzado para este espacio.');
    }
    throw Exception('No se pudo crear la nota (HTTP ${resp.statusCode}).');
  }

  static Future<void> actualizarNota(int espacioId, NotaEspacio nota) async {
    final headers = await _headers();
    final resp = await http.put(
      _u('/espacios/$espacioId/notas/${nota.id}'),
      headers: headers,
      body: jsonEncode(nota.toApiUpdate()),
    );
    if (resp.statusCode != 200) {
      throw Exception('No se pudo actualizar la nota (HTTP ${resp.statusCode}).');
    }
  }

  static Future<void> eliminarNota(int espacioId, int notaId) async {
    final headers = await _headers();
    final resp = await http.delete(_u('/espacios/$espacioId/notas/$notaId'), headers: headers);
    if (resp.statusCode != 200) {
      throw Exception('No se pudo eliminar la nota (HTTP ${resp.statusCode}).');
    }
  }

  // ==================== API: Semáforo ====================
  static Future<void> actualizarSemaforo(int espacioId, SeguridadEspacio nuevo) async {
    int? n;
    switch (nuevo) {
      case SeguridadEspacio.inseguro: n = 0; break;
      case SeguridadEspacio.parcialmenteSeguro: n = 1; break;
      case SeguridadEspacio.seguro: n = 2; break;
      case SeguridadEspacio.ninguno: n = null; break;
    }
    if (n == null) throw Exception('Valor de semáforo inválido.');

    final headers = await _headers();
    final resp = await http.patch(_u('/espacios/$espacioId/semaforo?n=$n'), headers: headers);
    if (resp.statusCode != 200) {
      throw Exception('No se pudo actualizar el semáforo (HTTP ${resp.statusCode}).');
    }
  }
}
