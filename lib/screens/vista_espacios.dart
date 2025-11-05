// lib/screens/vista_espacios.dart
import 'dart:convert';
import 'package:chita_app/screens/map_detail.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/session_repository.dart';
import '../main.dart';

// =============== CONFIG API ===============
const String _baseUrl = 'http://157.137.187.110:8000';

// --- ENUM del semáforo (UI local; persistir opcional) ---
enum SeguridadEspacio { ninguno, inseguro, parcialmenteSeguro, seguro }

class NotaEspacio {
  final int id;
  final int espacioId;
  String contenido;

  NotaEspacio({
    required this.id,
    required this.espacioId,
    required this.contenido,
  });

  factory NotaEspacio.desdeApi(Map<String, dynamic> j) => NotaEspacio(
        id: (j['nota_id'] as num).toInt(),
        espacioId: (j['espacio_id'] as num).toInt(),
        contenido: (j['contenido'] as String? ?? '').trim(),
      );

  Map<String, dynamic> aApiActualizacion() => {'contenido': contenido};
}

// --- mapping nombre -> asset (para los 5 por defecto) ---
String _assetParaTituloEspacio(String nombre) {
  switch (nombre.trim()) {
    case 'Parque La Encantada':
      return 'assets/parque_la_encantada.jpg';
    case 'Parque Sierra de Álica':
      return 'assets/parque_sierra_de_alica.jpg';
    case 'La Purísima':
      return 'assets/La_purisima.jpg';
    case 'Parque Ramón López Velarde':
      return 'assets/ramon.jpg';
    case 'Parque Arroyo de la Plata':
      return 'assets/plata.jpg';
    default:
      return 'assets/placeholder.jpg';
  }
}

class EspacioParaCorrer {
  final int? espacioId;
  final int? corredorId;

  final String rutaImagen;
  final String titulo;
  final String rutaImagenMapa;
  final String coordenadas; // usado solo al abrir el mapa
  final String? enlace;

  SeguridadEspacio semaforo; // mapeado desde 'semaforo' del backend
  List<NotaEspacio> notas;

  EspacioParaCorrer({
    required this.titulo,
    required this.coordenadas,
    this.enlace,
    this.espacioId,
    this.corredorId,
    String? rutaImagen,
    this.rutaImagenMapa = 'assets/map.png',
    this.semaforo = SeguridadEspacio.ninguno,
    List<NotaEspacio>? notas,
  })  : rutaImagen = rutaImagen ?? _assetParaTituloEspacio(titulo),
        notas = notas ?? [];

  static SeguridadEspacio _semaforoDesdeDb(int? n) {
    if (n == null) return SeguridadEspacio.ninguno;
    switch (n) {
      case 0:
        return SeguridadEspacio.inseguro;
      case 1:
        return SeguridadEspacio.parcialmenteSeguro;
      case 2:
        return SeguridadEspacio.seguro;
      default:
        return SeguridadEspacio.ninguno;
    }
  }

  factory EspacioParaCorrer.desdeJson(Map<String, dynamic> j) {
    final enlace = (j['enlaceUbicacion'] as String?)?.trim();
    final parsed = _parsearLatLngDeEnlaceOTexto(enlace ?? '');
    final coordsText = (parsed != null)
        ? 'Coordenadas: ${parsed.$1}, ${parsed.$2}'
        : 'Coordenadas no disponibles';

    final nombre = (j['nombreEspacio'] as String?)?.trim() ?? 'Sin nombre';
    final n = (j['semaforo'] as num?)?.toInt();

    return EspacioParaCorrer(
      espacioId: (j['espacio_id'] as num?)?.toInt(),
      corredorId: (j['corredor_id'] as num?)?.toInt(),
      titulo: nombre,
      enlace: (enlace?.isEmpty == true) ? null : enlace,
      coordenadas: coordsText,
      rutaImagen: _assetParaTituloEspacio(nombre),
      semaforo: _semaforoDesdeDb(n),
    );
  }
}

// ====== HELPERS de coordenadas ======
bool _esUrlProbable(String s) => s.startsWith('http://') || s.startsWith('https://');

(String, String)? _parsearLatLngDeEnlaceOTexto(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  // 1) "lat,lng" plano
  final plain = RegExp(r'^\s*(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)\s*$');
  final mPlain = plain.firstMatch(text);
  if (mPlain != null) return (mPlain.group(1)!, mPlain.group(2)!);

  // 2) "geo:lat,lng"
  final geo = RegExp(r'^geo:\s*(-?\d{1,3}(?:\.\d+)?),\s*(-?\d{1,3}(?:\.\d+)?)');
  final mGeo = geo.firstMatch(text);
  if (mGeo != null) return (mGeo.group(1)!, mGeo.group(2)!);

  // 3) URLs (Google Maps typical patterns)
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

    // @lat,lng en el path
    final s = text;
    final at = RegExp(r'@(-?\d{1,3}(?:\.\d+)?),\s*(-?\d{1,3}(?:\.\d+)?)');
    final mAt = at.firstMatch(s);
    if (mAt != null) return (mAt.group(1)!, mAt.group(2)!);

    // !3d<lat>!4d<lng> (deep params)
    final bang = RegExp(r'!3d(-?\d{1,3}(?:\.\d+)?)!4d(-?\d{1,3}(?:\.\d+)?)');
    final mBang = bang.firstMatch(s);
    if (mBang != null) return (mBang.group(1)!, mBang.group(2)!);
  }

  return null;
}

String _urlMapsCanonicaDesdeLatLng(String lat, String lng) =>
    'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

/// Sigue redirecciones para resolver short-links y tratar de extraer lat/lng.
/// Si no encuentra coordenadas, retorna null.
Future<(String, String)?> _resolverLatLngDesdeCualquierEnlace(String raw) async {
  final direct = _parsearLatLngDeEnlaceOTexto(raw);
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

      // ¿Ya contiene coordenadas la URL actual?
      final parsedHere = _parsearLatLngDeEnlaceOTexto(current.toString());
      if (parsedHere != null) return parsedHere;

      // Manejo de 3xx con header Location
      if (status >= 300 && status < 400) {
        final loc = streamed.headers['location'];
        if (loc == null || loc.isEmpty) break;

        Uri next = Uri.parse(Uri.decodeFull(loc));
        // Si viene envuelta en ?link=...
        final inner = next.queryParameters['link'];
        if (inner != null && inner.isNotEmpty) {
          next = Uri.parse(Uri.decodeFull(inner));
        }
        current = next;
        continue;
      }

      // Intento: meta refresh en body
      final body = await streamed.stream.bytesToString();
      final meta = RegExp(
        r"""http-equiv=["']refresh["'][^>]*content=["'][^;]*;\s*url=([^"']+)["']""",
        caseSensitive: false,
      );
      final m = meta.firstMatch(body);
      if (m != null) {
        final redirected = Uri.parse(Uri.decodeFull(m.group(1)!));
        final parsedMeta = _parsearLatLngDeEnlaceOTexto(redirected.toString());
        if (parsedMeta != null) return parsedMeta;

        final inner2 = redirected.queryParameters['link'];
        if (inner2 != null && inner2.isNotEmpty) {
          final innerUri = Uri.parse(Uri.decodeFull(inner2));
          final parsedInner = _parsearLatLngDeEnlaceOTexto(innerUri.toString());
          if (parsedInner != null) return parsedInner;
          current = innerUri;
          continue;
        }
      }
      break;
    }
  } catch (_) {
  } finally {
    client.close();
  }
  return null;
}

class VistaEspacios extends StatefulWidget {
  const VistaEspacios({super.key});

  @override
  State<VistaEspacios> createState() => EstadoVistaEspacios();
}

class EstadoVistaEspacios extends State<VistaEspacios> {
  final List<EspacioParaCorrer> _espaciosApi = [];
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _listarEspacios();
  }

  Future<Map<String, String>> _encabezadosAuth() async {
    final cid = await RepositorioSesion.obtenerCorredorId();
    final pass = await RepositorioSesion.obtenerContrasenia();
    if (cid == null || pass == null || pass.isEmpty) {
      throw Exception('Sesión inválida: faltan credenciales.');
    }
    return {
      'X-Corredor-Id': cid.toString(),
      'X-Contrasenia': pass,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  void _mostrarSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ===== Notas: API =====
  Future<List<NotaEspacio>> _listarNotasDeEspacio(int espacioId) async {
    try {
      final headers = await _encabezadosAuth();
      final url = Uri.parse('$_baseUrl/espacios/$espacioId/notas');
      final resp = await http.get(url, headers: headers);
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        return list.map((e) => NotaEspacio.desdeApi(e as Map<String, dynamic>)).toList();
      } else {
        _mostrarSnack('No se pudieron cargar notas (HTTP ${resp.statusCode}).', error: true);
      }
    } catch (e) {
      _mostrarSnack('Error al obtener notas: $e', error: true);
    }
    return <NotaEspacio>[];
  }

  Future<NotaEspacio?> _crearNotaApi(int espacioId, String contenido) async {
    try {
      final headers = await _encabezadosAuth();
      final url = Uri.parse('$_baseUrl/espacios/$espacioId/notas');
      final resp = await http.post(url, headers: headers, body: jsonEncode({'contenido': contenido}));
      if (resp.statusCode == 201) {
        return NotaEspacio.desdeApi(jsonDecode(resp.body) as Map<String, dynamic>);
      } else if (resp.statusCode == 409) {
        _mostrarSnack('Límite de 5 notas alcanzado para este espacio.', error: true);
      } else {
        _mostrarSnack('No se pudo crear la nota (HTTP ${resp.statusCode}).', error: true);
      }
    } catch (e) {
      _mostrarSnack('Error al crear nota: $e', error: true);
    }
    return null;
  }

  Future<bool> _actualizarNotaApi(int espacioId, NotaEspacio nota) async {
    try {
      final headers = await _encabezadosAuth();
      final url = Uri.parse('$_baseUrl/espacios/$espacioId/notas/${nota.id}');
      final resp = await http.put(url, headers: headers, body: jsonEncode(nota.aApiActualizacion()));
      if (resp.statusCode == 200) return true;
      _mostrarSnack('No se pudo actualizar la nota (HTTP ${resp.statusCode}).', error: true);
    } catch (e) {
      _mostrarSnack('Error al actualizar nota: $e', error: true);
    }
    return false;
  }

  Future<bool> _eliminarNotaApi(int espacioId, int notaId) async {
    try {
      final headers = await _encabezadosAuth();
      final url = Uri.parse('$_baseUrl/espacios/$espacioId/notas/$notaId');
      final resp = await http.delete(url, headers: headers);
      if (resp.statusCode == 200) return true;
      _mostrarSnack('No se pudo eliminar la nota (HTTP ${resp.statusCode}).', error: true);
    } catch (e) {
      _mostrarSnack('Error al eliminar nota: $e', error: true);
    }
    return false;
  }

  // ===== Espacios: listar/crear =====
  Future<void> _listarEspacios() async {
    setState(() => _cargando = true);
    try {
      final headers = await _encabezadosAuth();
      final url = Uri.parse('$_baseUrl/espacios');
      final resp = await http.get(url, headers: headers);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        final items =
            data.map((e) => EspacioParaCorrer.desdeJson(e as Map<String, dynamic>)).toList();

        setState(() {
          _espaciosApi
            ..clear()
            ..addAll(items);
        });

        await Future.wait(_espaciosApi.where((s) => s.espacioId != null).map((s) async {
          final notas = await _listarNotasDeEspacio(s.espacioId!);
          setState(() => s.notas = notas);
        }));
      } else {
        _mostrarSnack('No se pudo obtener la lista de espacios (HTTP ${resp.statusCode}).', error: true);
      }
    } catch (e) {
      _mostrarSnack('Error al obtener espacios: $e', error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Crea un espacio **solo si** el link contiene coordenadas (cuando hay internet).
  /// Si **no hay internet**, se guarda tal cual el link proporcionado (sin validar).
  Future<void> _agregarEspacio(String nombre, String? enlace) async {
    final nombreTrim = nombre.trim();
    final enlaceTrim = (enlace ?? '').trim();

    if (nombreTrim.isEmpty) {
      _mostrarSnack('El nombre es obligatorio.', error: true);
      return;
    }
    if (enlaceTrim.isEmpty) {
      _mostrarSnack('El link es obligatorio.', error: true);
      return;
    }

    // 🔎 Validación condicionada a conectividad:
    final conn = await Connectivity().checkConnectivity();
    (String, String)? coords;

    if (conn != ConnectivityResult.none) {
      // Con internet: solo aceptamos si se puede extraer lat/lng.
      coords = _parsearLatLngDeEnlaceOTexto(enlaceTrim);
      if (coords == null && _esUrlProbable(enlaceTrim)) {
        coords = await _resolverLatLngDesdeCualquierEnlace(enlaceTrim);
      }
      if (coords == null) {
        _mostrarSnack(
          'URL inválida: solo se aceptan enlaces con latitud y longitud (p. ej. "22.77,-102.58" o un link de Maps que incluya coordenadas).',
          error: true,
        );
        return;
      }
    } else {
      // Sin internet: se guarda tal cual (sin validar).
      coords = null;
    }

    // Si detectamos coords y hay internet, normalizamos a URL canónica; si no, lo que puso el usuario.
    final enlaceParaGuardar =
        (coords != null) ? _urlMapsCanonicaDesdeLatLng(coords.$1, coords.$2) : enlaceTrim;

    try {
      final headers = await _encabezadosAuth();
      final url = Uri.parse('$_baseUrl/espacios');

      final body = jsonEncode({
        'nombreEspacio': nombreTrim,
        'enlaceUbicacion': enlaceParaGuardar,
      });

      final resp = await http.post(url, headers: headers, body: body);
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;

        // Intentamos deducir coords SOLO para la pantalla de mapa; no se muestran en la lista.
        final parsedAfter =
            _parsearLatLngDeEnlaceOTexto(j['enlaceUbicacion'] as String? ?? '');
        final coordsText = (parsedAfter != null)
            ? 'Coordenadas: ${parsedAfter.$1}, ${parsedAfter.$2}'
            : 'Coordenadas no disponibles';

        final creado = EspacioParaCorrer(
          espacioId: (j['espacio_id'] as num?)?.toInt(),
          corredorId: (j['corredor_id'] as num?)?.toInt(),
          titulo: (j['nombreEspacio'] as String?)?.trim() ?? 'Sin nombre',
          enlace: ((j['enlaceUbicacion'] as String?)?.trim().isEmpty ?? true)
              ? null
              : (j['enlaceUbicacion'] as String).trim(),
          coordenadas: coordsText,
          rutaImagen: _assetParaTituloEspacio((j['nombreEspacio'] as String?)?.trim() ?? ''),
        );

        setState(() {
          _espaciosApi.insert(0, creado);
        });

        _mostrarSnack('Espacio agregado.');
      } else if (resp.statusCode == 422) {
        _mostrarSnack('Datos inválidos (422). Revisa nombre y enlace.', error: true);
      } else {
        _mostrarSnack('No se pudo crear el espacio (HTTP ${resp.statusCode}).', error: true);
      }
    } catch (e) {
      _mostrarSnack('Error al crear espacio: $e', error: true);
    }
  }

  Future<void> _abrirEnMapa(EspacioParaCorrer espacio) async {
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) {
      _mostrarSnack('No hay conexión para mostrar el mapa.', error: true);
      return;
    }

    String? lat;
    String? lng;

    if ((espacio.enlace ?? '').isNotEmpty) {
      final resolved = await _resolverLatLngDesdeCualquierEnlace(espacio.enlace!.trim());
      if (resolved != null) {
        lat = resolved.$1;
        lng = resolved.$2;
      }
    }
    if (lat == null || lng == null) {
      final parsed = _parsearLatLngDeEnlaceOTexto(
        espacio.coordenadas.replaceFirst('Coordenadas:', '').trim(),
      );
      if (parsed != null) {
        lat = parsed.$1;
        lng = parsed.$2;
      }
    }
    if (lat == null || lng == null) {
      _mostrarSnack('No se pudieron resolver coordenadas de este link.', error: true);
      return;
    }

    final routeCoords = 'Coordenadas: $lat, $lng';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapDetailScreen(
          routeTitle: espacio.titulo,
          routeCoordinates: routeCoords,
          mapImagePath: espacio.rutaImagenMapa,
        ),
      ),
    );
  }

  void _mostrarModalAgregarEspacio() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: HojaAgregarEspacio(onAddSpace: _agregarEspacio),
        );
      },
    );
  }

  void _mostrarModalAgregarNota(EspacioParaCorrer espacio) {
    if (espacio.espacioId == null) {
      _mostrarSnack('Para agregar notas, primero guarda este espacio en tu cuenta.', error: true);
      return;
    }
    if (espacio.notas.length >= 5) {
      _mostrarSnack('No puedes agregar más de 5 notas por espacio.', error: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: HojaAgregarEditarNota(
            onSave: (nuevaNota) async {
              final trimmed = nuevaNota.trim();
              if (trimmed.isEmpty) {
                _mostrarSnack('La nota no puede estar vacía.', error: true);
                return;
              }
              final creada = await _crearNotaApi(espacio.espacioId!, trimmed);
              if (creada != null) {
                setState(() => espacio.notas.add(creada));
                _mostrarSnack('Nota agregada.');
              }
            },
          ),
        );
      },
    );
  }

  void _mostrarModalEditarNota(EspacioParaCorrer espacio, int idxNota) {
    if (espacio.espacioId == null) return;
    final nota = espacio.notas[idxNota];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: HojaAgregarEditarNota(
            notaInicial: nota.contenido,
            onSave: (editada) async {
              final trimmed = editada.trim();
              if (trimmed.isEmpty) {
                _mostrarSnack('La nota no puede estar vacía.', error: true);
                return;
              }
              final respaldo = nota.contenido;
              setState(() => nota.contenido = trimmed);
              final ok = await _actualizarNotaApi(espacio.espacioId!, nota);
              if (ok) {
                _mostrarSnack('Nota actualizada.');
              } else {
                setState(() => nota.contenido = respaldo);
              }
            },
          ),
        );
      },
    );
  }

  void _eliminarNota(EspacioParaCorrer espacio, int idxNota) async {
    if (espacio.espacioId == null) return;
    final nota = espacio.notas[idxNota];
    final ok = await _eliminarNotaApi(espacio.espacioId!, nota.id);
    if (ok) {
      setState(() => espacio.notas.removeAt(idxNota));
      _mostrarSnack('Nota eliminada.');
    }
  }

  Future<bool> _actualizarSemaforoApi(int espacioId, SeguridadEspacio nuevo) async {
    try {
      final headers = await _encabezadosAuth();
      final n = () {
        switch (nuevo) {
          case SeguridadEspacio.inseguro:
            return 0;
          case SeguridadEspacio.parcialmenteSeguro:
            return 1;
          case SeguridadEspacio.seguro:
            return 2;
          case SeguridadEspacio.ninguno:
            return null; // no se usa en el slider
        }
      }();
      if (n == null) return false;
      final url = Uri.parse('$_baseUrl/espacios/$espacioId/semaforo?n=$n');
      final resp = await http.patch(url, headers: headers);
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _actualizarSemaforo(EspacioParaCorrer espacio, SeguridadEspacio nuevo) async {
    if (espacio.espacioId == null) {
      _mostrarSnack('Primero guarda este espacio en tu cuenta para poder calificarlo.', error: true);
      return;
    }
    final prev = espacio.semaforo;
    setState(() => espacio.semaforo = nuevo); // actualización optimista
    final ok = await _actualizarSemaforoApi(espacio.espacioId!, nuevo);
    if (!ok) {
      setState(() => espacio.semaforo = prev); // revertir si falló
      _mostrarSnack('No se pudo actualizar el semáforo. Intenta de nuevo.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lista = _espaciosApi; // solo API

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (_cargando) const LinearProgressIndicator(minHeight: 2),
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Espacios para correr',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _listarEspacios,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualizar'),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      lista.isEmpty ? 'Sin espacios' : '${lista.length} espacio(s)',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...lista.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: TarjetaEspacio(
                      espacio: e,
                      onAgregarNota: () => _mostrarModalAgregarNota(e),
                      onEliminarNota: (i) => _eliminarNota(e, i),
                      onEditarNota: (i) => _mostrarModalEditarNota(e, i),
                      onCambiarSemaforo: (s) => _actualizarSemaforo(e, s),
                      onVerMapa: () => _abrirEnMapa(e),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: ElevatedButton.icon(
                onPressed: _mostrarModalAgregarEspacio,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Agregar espacio'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MODAL para agregar nuevo espacio ---
class HojaAgregarEspacio extends StatefulWidget {
  final Future<void> Function(String nombre, String? enlace) onAddSpace;
  const HojaAgregarEspacio({required this.onAddSpace});

  @override
  State<HojaAgregarEspacio> createState() => EstadoHojaAgregarEspacio();
}

class EstadoHojaAgregarEspacio extends State<HojaAgregarEspacio> {
  final _claveFormulario = GlobalKey<FormState>();
  final _ctrlNombre = TextEditingController();
  final _ctrlEnlace = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _ctrlNombre.dispose();
    _ctrlEnlace.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_claveFormulario.currentState!.validate()) return;

    setState(() => _guardando = true);
    try {
      await widget.onAddSpace(
        _ctrlNombre.text.trim(),
        _ctrlEnlace.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: const BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Form(
        key: _claveFormulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Agregar Nuevo Espacio',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: _guardando ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ctrlNombre,
              decoration: const InputDecoration(labelText: 'Nombre del espacio *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un nombre.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ctrlEnlace,
              decoration: const InputDecoration(
                labelText: 'Link del espacio *',
                hintText: 'https://maps.app.goo.gl/… / https://maps.google.com/… / o lat,lng',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa un link.' : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _guardando ? null : _enviar,
                child: _guardando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Agregar Espacio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MODAL para agregar/editar nota ---
class HojaAgregarEditarNota extends StatefulWidget {
  final String? notaInicial;
  final Function(String) onSave;

  const HojaAgregarEditarNota({this.notaInicial, required this.onSave});

  @override
  State<HojaAgregarEditarNota> createState() => EstadoHojaAgregarEditarNota();
}

class EstadoHojaAgregarEditarNota extends State<HojaAgregarEditarNota> {
  late final TextEditingController _ctrlNota;

  @override
  void initState() {
    super.initState();
    _ctrlNota = TextEditingController(text: widget.notaInicial);
  }

  @override
  void dispose() {
    _ctrlNota.dispose();
    super.dispose();
  }

  void _enviar() {
    widget.onSave(_ctrlNota.text.trim());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.notaInicial != null;

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            editando ? 'Editar Nota' : 'Agregar Nota Nueva',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrlNota,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Escribe tus notas aquí...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _enviar,
              child: const Text('Guardar Nota'),
            ),
          ),
        ],
      ),
    );
  }
}

// --- CARD de espacio ---
class TarjetaEspacio extends StatelessWidget {
  final EspacioParaCorrer espacio;
  final VoidCallback onAgregarNota;
  final Function(int) onEliminarNota;
  final Function(int) onEditarNota;
  final Function(SeguridadEspacio) onCambiarSemaforo;
  final VoidCallback onVerMapa;

  const TarjetaEspacio({
    required this.espacio,
    required this.onAgregarNota,
    required this.onEliminarNota,
    required this.onEditarNota,
    required this.onCambiarSemaforo,
    required this.onVerMapa,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            espacio.rutaImagen,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, _, __) => Container(
              height: 150,
              color: Colors.grey[800],
              child: const Center(
                child: Icon(Icons.image_not_supported, color: Colors.white54, size: 50),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        espacio.titulo,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.note_add_outlined),
                      onPressed: onAgregarNota,
                      tooltip: 'Agregar nota (máx. 5)',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ControlSemaforo(
                  semaforo: espacio.semaforo,
                  onChanged: (nuevo) => onCambiarSemaforo(nuevo),
                ),
                if (espacio.notas.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: espacio.notas.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final NotaEspacio nota = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Colors.grey)),
                            Expanded(
                              child: Text(
                                nota.contenido,
                                style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                            ),
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 18,
                                icon: const Icon(Icons.edit, color: Colors.white54),
                                onPressed: () => onEditarNota(idx),
                              ),
                            ),
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 20,
                                icon: const Icon(Icons.delete_outline, color: Colors.white54),
                                onPressed: () => onEliminarNota(idx),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onVerMapa,
                    child: const Text('Ver en Mapa'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- SLIDER del semáforo (UI local) ---
class ControlSemaforo extends StatelessWidget {
  final SeguridadEspacio semaforo;
  final Function(SeguridadEspacio) onChanged;

  const ControlSemaforo({
    required this.semaforo,
    required this.onChanged,
  });

  double _valorSlider(SeguridadEspacio s) {
    switch (s) {
      case SeguridadEspacio.inseguro:
        return 0.0;
      case SeguridadEspacio.parcialmenteSeguro:
        return 1.0;
      case SeguridadEspacio.seguro:
        return 2.0;
      case SeguridadEspacio.ninguno:
      default:
        return 1.0;
    }
  }

  String _etiqueta(SeguridadEspacio s) {
    switch (s) {
      case SeguridadEspacio.inseguro:
        return 'Inseguro';
      case SeguridadEspacio.parcialmenteSeguro:
        return 'Parcialmente Seguro';
      case SeguridadEspacio.seguro:
        return 'Seguro';
      case SeguridadEspacio.ninguno:
      default:
        return 'Sin calificar';
    }
  }

  Color _color(SeguridadEspacio s) {
    switch (s) {
      case SeguridadEspacio.inseguro:
        return Colors.redAccent;
      case SeguridadEspacio.parcialmenteSeguro:
        return Colors.orangeAccent;
      case SeguridadEspacio.seguro:
        return Colors.greenAccent;
      case SeguridadEspacio.ninguno:
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(semaforo);

    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              trackShape: const PistaDeslizadorGradiente(),
            ),
            child: Slider(
              value: _valorSlider(semaforo),
              min: 0,
              max: 2,
              divisions: 2,
              activeColor: color,
              inactiveColor: Colors.grey[700],
              onChanged: (v) {
                final nuevo = v == 0.0
                    ? SeguridadEspacio.inseguro
                    : v == 1.0
                        ? SeguridadEspacio.parcialmenteSeguro
                        : SeguridadEspacio.seguro;
                onChanged(nuevo);
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _etiqueta(semaforo),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class PistaDeslizadorGradiente extends SliderTrackShape with BaseSliderTrackShape {
  const PistaDeslizadorGradiente();

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    const gradient = LinearGradient(
      colors: [Colors.red, Colors.yellow, Colors.green],
    );

    final Paint paint = Paint()..shader = gradient.createShader(trackRect);

    context.canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, Radius.circular(trackRect.height / 2)),
      paint,
    );
  }
}
