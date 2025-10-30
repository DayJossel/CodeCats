import 'dart:convert';
import 'package:chita_app/screens/map_detail.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


import '../core/session_repository.dart';
import '../main.dart';

// =============== CONFIG API ===============
const String _baseUrl = 'http://157.137.187.110:8000';

// --- NUEVO ENUM PARA EL SISTEMA DE 3 PUNTOS (se mantiene, no se persiste aún) ---
enum SpaceSafety { none, unsafe, partiallySafe, safe }

// --- MODELO DE DATOS ACTUALIZADO (incluye campos del API) ---
class RunningSpace {
  final int? espacioId;
  final int? corredorId;
  final bool esInicial;

  final String imagePath;     // UI local (placeholder)
  final String title;         // nombreEspacio
  final String mapImagePath;  // UI local (placeholder)
  final String coordinates;   // texto mostrado en la tarjeta (derivado)
  final String? link;         // enlaceUbicacion

  // Campos de UI local (no persistidos en este CU)
  SpaceSafety safety;
  List<String> notes;

  RunningSpace({
    required this.title,
    required this.coordinates,
    this.link,
    this.espacioId,
    this.corredorId,
    this.esInicial = false,
    this.imagePath = 'assets/placeholder.jpg',
    this.mapImagePath = 'assets/map.png',
    this.safety = SpaceSafety.none,
    List<String>? notes,
  }) : notes = notes ?? [];

  // Factory desde JSON del API
  factory RunningSpace.fromJson(Map<String, dynamic> j) {
    final link = (j['enlaceUbicacion'] as String?)?.trim();
    final parsed = _parseLatLngFromLinkOrText(link ?? '');
    final coordsText = (parsed != null)
        ? 'Coordenadas: ${parsed.$1}, ${parsed.$2}'
        : (link == null || link.isEmpty)
            ? 'Coordenadas no disponibles'
            : 'Link: $link';

    return RunningSpace(
      espacioId: (j['espacio_id'] as num?)?.toInt(),
      corredorId: (j['corredor_id'] as num?)?.toInt(),
      esInicial: (j['es_inicial'] as bool?) ?? false,
      title: (j['nombreEspacio'] as String?)?.trim() ?? 'Sin nombre',
      link: (link?.isEmpty == true) ? null : link,
      coordinates: coordsText,
    );
  }

  // Para POST (crear)
  Map<String, dynamic> toCreateBody() => {
        'nombreEspacio': title,
        'enlaceUbicacion': link ?? '',
        'es_inicial': false,
      };
}

// ====== HELPERS: validación y extracción de lat,lng desde links/texto ======
bool _isLikelyUrl(String s) => s.startsWith('http://') || s.startsWith('https://');

/// Devuelve (lat,lng) si encuentra coordenadas en:
/// - ?q=lat,lng
/// - @lat,lng
/// - !3dLAT!4dLNG
/// - texto "lat,lng" suelto
/// Si no hay, devuelve null.
(String, String)? _parseLatLngFromLinkOrText(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  // A) "lat,lng" plano
  final plain = RegExp(r'^\s*(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)\s*$');
  final mPlain = plain.firstMatch(text);
  if (mPlain != null) return (mPlain.group(1)!, mPlain.group(2)!);

  // B) geo:lat,lng
  final geo = RegExp(r'^geo:\s*(-?\d{1,3}(?:\.\d+)?),\s*(-?\d{1,3}(?:\.\d+)?)');
  final mGeo = geo.firstMatch(text);
  if (mGeo != null) return (mGeo.group(1)!, mGeo.group(2)!);

  // C) Si es URL, intentamos varios patrones
  if (_isLikelyUrl(text)) {
    final uri = Uri.tryParse(text);

    // ?q=lat,lng
    final q = uri?.queryParameters['q'];
    if (q != null) {
      final mq = plain.firstMatch(q);
      if (mq != null) return (mq.group(1)!, mq.group(2)!);
    }

    // ?ll=lat,lng (también lo usa Google)
    final ll = uri?.queryParameters['ll'];
    if (ll != null) {
      final mll = plain.firstMatch(ll);
      if (mll != null) return (mll.group(1)!, mll.group(2)!);
    }

    // search/?api=1&query=lat,lng
    final query = uri?.queryParameters['query'];
    if (query != null) {
      final mQuery = plain.firstMatch(query);
      if (mQuery != null) return (mQuery.group(1)!, mQuery.group(2)!);
    }

    final s = text;

    // @lat,lng
    final at = RegExp(r'@(-?\d{1,3}(?:\.\d+)?),\s*(-?\d{1,3}(?:\.\d+)?)');
    final mAt = at.firstMatch(s);
    if (mAt != null) return (mAt.group(1)!, mAt.group(2)!);

    // !3dLAT!4dLNG
    final bang = RegExp(r'!3d(-?\d{1,3}(?:\.\d+)?)!4d(-?\d{1,3}(?:\.\d+)?)');
    final mBang = bang.firstMatch(s);
    if (mBang != null) return (mBang.group(1)!, mBang.group(2)!);
  }

  return null;
}

String _canonicalGoogleMapsUrlFromLatLng(String lat, String lng) =>
    'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

Future<(String, String)?> _resolveLatLngFromAnyLink(String raw) async {
  // 1) ¿ya hay lat,lng directo?
  final direct = _parseLatLngFromLinkOrText(raw);
  if (direct != null) return direct;

  // 2) Si no parece URL, no se puede resolver
  if (!_isLikelyUrl(raw)) return null;

  final client = http.Client();
  try {
    Uri current = Uri.parse(raw);

    for (int i = 0; i < 6; i++) {
      final req = http.Request('GET', current);
      // No sigas redirects automáticamente: queremos leer Location
      req.followRedirects = false;
      req.headers['User-Agent'] = 'Mozilla/5.0 (Flutter; Dart)';

      final streamed = await client.send(req);
      final status = streamed.statusCode;

      // a) Intenta parsear coords de la URL actual
      final parsedHere = _parseLatLngFromLinkOrText(current.toString());
      if (parsedHere != null) return parsedHere;

      // b) Si es redirección, mira el Location
      if (status >= 300 && status < 400) {
        final loc = streamed.headers['location'];
        if (loc == null || loc.isEmpty) break;

        // Puede venir algo como .../?link=https%3A%2F%2Fwww.google.com%2Fmaps%2F...
        Uri next = Uri.parse(Uri.decodeFull(loc));

        // Si trae ?link=, úsalo (suele ser la URL grande con coords o @lat,lng)
        final inner = next.queryParameters['link'];
        if (inner != null && inner.isNotEmpty) {
          next = Uri.parse(Uri.decodeFull(inner));
        }

        // Próximo salto
        current = next;
        // intentamos en el siguiente loop
        continue;
      }

      // c) No hay redirect: intentemos body por <meta http-equiv="refresh" ...>
      final body = await streamed.stream.bytesToString();
      final meta = RegExp(
        r"""http-equiv=["']refresh["'][^>]*content=["'][^;]*;\s*url=([^"']+)["']""",
        caseSensitive: false,
      );
      final m = meta.firstMatch(body);
      if (m != null) {
        final redirected = Uri.parse(Uri.decodeFull(m.group(1)!));
        final parsedMeta = _parseLatLngFromLinkOrText(redirected.toString());
        if (parsedMeta != null) return parsedMeta;

        // Si ese meta trae link=, también lo abrimos
        final inner2 = redirected.queryParameters['link'];
        if (inner2 != null && inner2.isNotEmpty) {
          final innerUri = Uri.parse(Uri.decodeFull(inner2));
          final parsedInner = _parseLatLngFromLinkOrText(innerUri.toString());
          if (parsedInner != null) return parsedInner;

          // Reintenta como "siguiente" URL
          current = innerUri;
          continue;
        }
      }

      // Si llegamos aquí y nada, paramos.
      break;
    }
  } catch (_) {
    // silencio: devolvemos null abajo
  } finally {
    client.close();
  }

  return null;
}


class VistaEspacios extends StatefulWidget {
  const VistaEspacios({super.key});

  @override
  State<VistaEspacios> createState() => _VistaEspaciosState();
}

class _VistaEspaciosState extends State<VistaEspacios> {
  // ===== 5 ESPACIOS POR DEFECTO (los que ya tenías) =====
  final List<RunningSpace> _defaultSpaces = [
    RunningSpace(
      imagePath: 'assets/parque_la_encantada.jpg',
      title: 'Parque La Encantada',
      mapImagePath: 'assets/map.png',
      coordinates: 'Coordenadas: 22.7597523, -102.5788378',
      link: null,
    ),
    RunningSpace(
      imagePath: 'assets/parque_sierra_de_alica.jpg',
      title: 'Parque Sierra de Álica',
      mapImagePath: 'assets/map.png',
      coordinates: 'Coordenadas: 22.7696141, -102.5767151',
      link: null,
      safety: SpaceSafety.safe,
    ),
    RunningSpace(
      imagePath: 'assets/La_purisima.jpg',
      title: 'La Purísima',
      mapImagePath: 'assets/map.png',
      coordinates: 'Coordenadas: 22.7496541, -102.5238082',
      link: null,
      safety: SpaceSafety.partiallySafe,
    ),
    RunningSpace(
      imagePath: 'assets/ramon.jpg',
      title: 'Parque Ramón López Velarde',
      mapImagePath: 'assets/map.png',
      coordinates: 'Coordenadas: 22.7582581, -102.5417730',
      link: null,
      safety: SpaceSafety.unsafe,
    ),
    RunningSpace(
      imagePath: 'assets/plata.jpg',
      title: 'Parque Arroyo de la Plata',
      mapImagePath: 'assets/map.png',
      coordinates: 'Coordenadas: 22.7569926, -102.5387186',
      link: null,
    ),
  ];

  // ===== Espacios del backend (usuario) =====
  final List<RunningSpace> _apiSpaces = [];

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchSpaces();
  }

  Future<Map<String, String>> _authHeaders() async {
    final cid = await SessionRepository.corredorId();
    final pass = await SessionRepository.contrasenia();

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

  Future<void> _fetchSpaces() async {
    setState(() => _loading = true);
    try {
      final headers = await _authHeaders();
      final url = Uri.parse('$_baseUrl/espacios');
      final resp = await http.get(url, headers: headers);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        final items =
            data.map((e) => RunningSpace.fromJson(e as Map<String, dynamic>)).toList();
        setState(() {
          _apiSpaces
            ..clear()
            ..addAll(items);
        });
      } else {
        _showSnack('No se pudo obtener la lista de espacios (HTTP ${resp.statusCode}).',
            isError: true);
      }
    } catch (e) {
      _showSnack('Error al obtener espacios: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addSpace(String name, String? link) async {
    if (name.trim().isEmpty) {
      _showSnack('El nombre es obligatorio.', isError: true);
      return;
    }

    // --- Validación estricta de enlace (si viene) ---
    String? linkTrim = link?.trim();
    (String, String)? coordsFromLink;

    if (linkTrim != null && linkTrim.isNotEmpty) {
      // 1) "lat,lng" plano → directo
      final plain = _parseLatLngFromLinkOrText(linkTrim);
      if (plain != null) {
        coordsFromLink = plain;
      } else {
        // 2) URL (maps.app.goo.gl / google.com/maps / etc.) → resolver
        final conn = await Connectivity().checkConnectivity();
        if (conn == ConnectivityResult.none) {
          _showSnack(
            'No hay internet para validar el enlace. '
            'Usa formato "lat,lng" o intenta de nuevo con conexión.',
            isError: true,
          );
          return;
        }

        coordsFromLink = await _resolveLatLngFromAnyLink(linkTrim);
        if (coordsFromLink == null) {
          _showSnack(
            'El enlace no corresponde a una ubicación válida. '
            'Pega un link de Google Maps que apunte a una ubicación o usa "lat,lng".',
            isError: true,
          );
          return;
        }
      }
    }

    try {
      final headers = await _authHeaders();
      final url = Uri.parse('$_baseUrl/espacios');

      // ⬇️⬇️ ESTE ES EL CAMBIO CLAVE: canoniza si tienes coords
      final enlaceParaGuardar = (coordsFromLink != null)
          ? _canonicalGoogleMapsUrlFromLatLng(coordsFromLink.$1, coordsFromLink.$2)
          : (linkTrim ?? '');

      final body = jsonEncode({
        'nombreEspacio': name.trim(),
        'enlaceUbicacion': enlaceParaGuardar, // <-- aquí usamos la URL canonical
        'es_inicial': false,
      });

      final resp = await http.post(url, headers: headers, body: body);
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;

        // Mostrar coords en la tarjeta
        final coordsText = (coordsFromLink != null)
            ? 'Coordenadas: ${coordsFromLink.$1}, ${coordsFromLink.$2}'
            : (() {
                final parsedAfter = _parseLatLngFromLinkOrText(
                    j['enlaceUbicacion'] as String? ?? '');
                if (parsedAfter != null) {
                  return 'Coordenadas: ${parsedAfter.$1}, ${parsedAfter.$2}';
                }
                return 'Coordenadas no disponibles';
              })();

        final created = RunningSpace(
          espacioId: (j['espacio_id'] as num?)?.toInt(),
          corredorId: (j['corredor_id'] as num?)?.toInt(),
          esInicial: (j['es_inicial'] as bool?) ?? false,
          title: (j['nombreEspacio'] as String?)?.trim() ?? 'Sin nombre',
          link: ((j['enlaceUbicacion'] as String?)?.trim().isEmpty ?? true)
              ? null
              : (j['enlaceUbicacion'] as String).trim(),
          coordinates: coordsText,
        );

        setState(() {
          _apiSpaces.insert(0, created); // mantiene tus 5 defaults arriba
        });

        _showSnack('Espacio agregado.');
      } else if (resp.statusCode == 422) {
        _showSnack('Datos inválidos (422). Revisa nombre y enlace.', isError: true);
      } else {
        _showSnack(
          'No se pudo crear el espacio (HTTP ${resp.statusCode}).',
          isError: true,
        );
      }
    } catch (e) {
      _showSnack('Error al crear espacio: $e', isError: true);
    }
  }



  Future<void> _openOnMap(RunningSpace space) async {
    // Conectividad (el mapa en línea lo requiere)
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) {
      _showSnack('No hay conexión a internet para mostrar el mapa.', isError: true);
      return;
    }

    String routeCoords = space.coordinates;

    // a) Si hay link, intentamos resolverlo a lat,lng
    if ((space.link ?? '').isNotEmpty) {
      final resolved = await _resolveLatLngFromAnyLink(space.link!.trim());
      if (resolved != null) {
        routeCoords = 'Coordenadas: ${resolved.$1}, ${resolved.$2}';
      } else {
        // b) Si el link no trae coords, intentamos extraer de "Coordenadas: x, y" si existen
        final fromText = _parseLatLngFromLinkOrText(space.coordinates.replaceFirst('Coordenadas:', '').trim());
        if (fromText != null) {
          routeCoords = 'Coordenadas: ${fromText.$1}, ${fromText.$2}';
        }
        // c) Si tampoco, dejamos el texto como está (tu MapDetail tiene fallback interno)
      }
    } else {
      // No hay link: intentamos parsear coords del texto
      final fromText = _parseLatLngFromLinkOrText(space.coordinates.replaceFirst('Coordenadas:', '').trim());
      if (fromText != null) {
        routeCoords = 'Coordenadas: ${fromText.$1}, ${fromText.$2}';
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapDetailScreen(
          routeTitle: space.title,
          routeCoordinates: routeCoords,
          mapImagePath: space.mapImagePath,
        ),
      ),
    );
  }


  void _showAddSpaceModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _AddSpaceSheet(
            onAddSpace: _addSpace,
          ),
        );
      },
    );
  }

  // --- FUNCIÓN: límite de 5 notas (UI local, no persiste en este CU) ---
  void _showAddNoteModal(RunningSpace space) {
    if (space.notes.length >= 5) {
      _showSnack('No puedes agregar más de 5 notas por espacio.', isError: true);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _AddNoteSheet(
            onSave: (newNote) {
              setState(() {
                if (newNote.isNotEmpty) {
                  space.notes.add(newNote);
                }
              });
            },
          ),
        );
      },
    );
  }

  void _showEditNoteModal(RunningSpace space, int noteIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _AddNoteSheet(
            initialNote: space.notes[noteIndex],
            onSave: (editedNote) {
              setState(() {
                if (editedNote.isNotEmpty) {
                  space.notes[noteIndex] = editedNote;
                } else {
                  space.notes.removeAt(noteIndex);
                }
              });
            },
          ),
        );
      },
    );
  }

  void _deleteNote(RunningSpace space, int noteIndex) {
    setState(() {
      space.notes.removeAt(noteIndex);
    });
  }

  void _updateSafety(RunningSpace space, SpaceSafety newSafety) {
    setState(() {
      space.safety = newSafety; // UI local (otro CU)
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // combinamos 5 defaults + espacios del backend
    final combined = <RunningSpace>[..._defaultSpaces, ..._apiSpaces];

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
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
                      onPressed: _fetchSpaces,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualizar'),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      combined.isEmpty
                          ? 'Sin espacios'
                          : '${combined.length} espacio(s)',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...combined.map(
                  (space) => Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: _RouteCard(
                      space: space,
                      onAddNote: () => _showAddNoteModal(space),
                      onDeleteNote: (index) => _deleteNote(space, index),
                      onEditNote: (index) => _showEditNoteModal(space, index),
                      onSafetyChanged: (newSafety) => _updateSafety(space, newSafety),
                      onSeeMap: () => _openOnMap(space),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: ElevatedButton.icon(
                onPressed: _showAddSpaceModal,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Agregar espacio'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET PARA AGREGAR NUEVO ESPACIO (usa POST /espacios) ---
class _AddSpaceSheet extends StatefulWidget {
  final Future<void> Function(String name, String? link) onAddSpace;
  const _AddSpaceSheet({required this.onAddSpace});

  @override
  State<_AddSpaceSheet> createState() => _AddSpaceSheetState();
}

class _AddSpaceSheetState extends State<_AddSpaceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _linkController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await widget.onAddSpace(
        _nameController.text.trim(),
        _linkController.text.trim().isEmpty ? null : _linkController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // El onAddSpace ya muestra SnackBars; aquí solo aseguramos no cerrar.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      decoration: const BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20), topRight: Radius.circular(20),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Agregar Nuevo Espacio',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre del espacio *'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Ingresa un nombre.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _linkController,
              decoration: const InputDecoration(
                labelText: 'Link del espacio (opcional)',
                hintText: 'https://maps.google.com/… o lat,lng',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Agregar Espacio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET MODAL PARA AGREGAR/EDITAR NOTA (UI local) ---
class _AddNoteSheet extends StatefulWidget {
  final String? initialNote;
  final Function(String) onSave;

  const _AddNoteSheet({this.initialNote, required this.onSave});

  @override
  State<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends State<_AddNoteSheet> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSave(_noteController.text.trim());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialNote != null;

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20), topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEditing ? 'Editar Nota' : 'Agregar Nota Nueva',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
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
              onPressed: _submit,
              child: const Text('Guardar Nota'),
            ),
          ),
        ],
      ),
    );
  }
}

// --- TARJETA DE ESPACIO (se agrega callback onSeeMap) ---
class _RouteCard extends StatelessWidget {
  final RunningSpace space;
  final VoidCallback onAddNote;
  final Function(int) onDeleteNote;
  final Function(int) onEditNote;
  final Function(SpaceSafety) onSafetyChanged;
  final VoidCallback onSeeMap;

  const _RouteCard({
    required this.space,
    required this.onAddNote,
    required this.onDeleteNote,
    required this.onEditNote,
    required this.onSafetyChanged,
    required this.onSeeMap,
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
            space.imagePath,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 150,
                color: Colors.grey[800],
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    color: Colors.white54,
                    size: 50,
                  ),
                ),
              );
            },
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
                        space.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.note_add_outlined),
                      onPressed: onAddNote,
                      tooltip: 'Agregar nota (máx. 5)',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _SafetySlider(
                  safety: space.safety,
                  onChanged: (newSafety) => onSafetyChanged(newSafety),
                ),
                const SizedBox(height: 8),
                Text(
                  space.coordinates,
                  style: const TextStyle(color: Colors.white70),
                ),
                if (space.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: space.notes.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final note = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Colors.grey)),
                            Expanded(
                              child: Text(
                                note,
                                style: const TextStyle(
                                  color: Colors.grey, fontStyle: FontStyle.italic),
                              ),
                            ),
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 18,
                                icon: const Icon(Icons.edit, color: Colors.white54),
                                onPressed: () => onEditNote(idx),
                              ),
                            ),
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 20,
                                icon: const Icon(Icons.delete_outline, color: Colors.white54),
                                onPressed: () => onDeleteNote(idx),
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
                    onPressed: onSeeMap,
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

// --- SLIDER DE 3 PUNTOS (UI local; no persiste en este CU) ---
class _SafetySlider extends StatelessWidget {
  final SpaceSafety safety;
  final Function(SpaceSafety) onChanged;

  const _SafetySlider({
    required this.safety,
    required this.onChanged,
  });

  double _getSliderValue(SpaceSafety safety) {
    switch (safety) {
      case SpaceSafety.unsafe:
        return 0.0;
      case SpaceSafety.partiallySafe:
        return 1.0;
      case SpaceSafety.safe:
        return 2.0;
      case SpaceSafety.none:
      default:
        return 1.0;
    }
  }

  String _getLabel(SpaceSafety safety) {
    switch (safety) {
      case SpaceSafety.unsafe:
        return 'Inseguro';
      case SpaceSafety.partiallySafe:
        return 'Parcialmente Seguro';
      case SpaceSafety.safe:
        return 'Seguro';
      case SpaceSafety.none:
      default:
        return 'Sin calificar';
    }
  }

  Color _getColor(SpaceSafety safety) {
    switch (safety) {
      case SpaceSafety.unsafe:
        return Colors.redAccent;
      case SpaceSafety.partiallySafe:
        return Colors.orangeAccent;
      case SpaceSafety.safe:
        return Colors.greenAccent;
      case SpaceSafety.none:
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(safety);

    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              trackShape: const _GradientRectSliderTrackShape(),
            ),
            child: Slider(
              value: _getSliderValue(safety),
              min: 0,
              max: 2,
              divisions: 2,
              activeColor: color,
              inactiveColor: Colors.grey[700],
              onChanged: (value) {
                final newSafety = value == 0.0
                    ? SpaceSafety.unsafe
                    : value == 1.0
                        ? SpaceSafety.partiallySafe
                        : SpaceSafety.safe;
                onChanged(newSafety);
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _getLabel(safety),
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

// --- TRACK DEL SLIDER (UI) ---
class _GradientRectSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
  const _GradientRectSliderTrackShape();

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
      RRect.fromRectAndRadius(
        trackRect, Radius.circular(trackRect.height / 2)),
      paint,
    );
  }
}
