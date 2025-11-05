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
enum SpaceSafety { none, unsafe, partiallySafe, safe }

class SpaceNote {
  final int id;
  final int espacioId;
  String content;

  SpaceNote({
    required this.id,
    required this.espacioId,
    required this.content,
  });

  factory SpaceNote.fromApi(Map<String, dynamic> j) => SpaceNote(
        id: (j['nota_id'] as num).toInt(),
        espacioId: (j['espacio_id'] as num).toInt(),
        content: (j['contenido'] as String? ?? '').trim(),
      );

  Map<String, dynamic> toApiUpdate() => {'contenido': content};
}

// --- mapping nombre -> asset (para los 5 por defecto) ---
String _assetForSpaceTitle(String name) {
  switch (name.trim()) {
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

class RunningSpace {
  final int? espacioId;
  final int? corredorId;

  final String imagePath;
  final String title;
  final String mapImagePath;
  final String coordinates; // se usa solo al abrir el mapa
  final String? link;

  SpaceSafety safety; // mapeado desde 'semaforo' del backend
  List<SpaceNote> notes;

  RunningSpace({
    required this.title,
    required this.coordinates,
    this.link,
    this.espacioId,
    this.corredorId,
    String? imagePath,
    this.mapImagePath = 'assets/map.png',
    this.safety = SpaceSafety.none,
    List<SpaceNote>? notes,
  })  : imagePath = imagePath ?? _assetForSpaceTitle(title),
        notes = notes ?? [];

  static SpaceSafety _safetyFromDb(int? n) {
    if (n == null) return SpaceSafety.none;
    switch (n) {
      case 0:
        return SpaceSafety.unsafe;
      case 1:
        return SpaceSafety.partiallySafe;
      case 2:
        return SpaceSafety.safe;
      default:
        return SpaceSafety.none;
    }
  }

  factory RunningSpace.fromJson(Map<String, dynamic> j) {
    final link = (j['enlaceUbicacion'] as String?)?.trim();
    final parsed = _parseLatLngFromLinkOrText(link ?? '');
    final coordsText = (parsed != null)
        ? 'Coordenadas: ${parsed.$1}, ${parsed.$2}'
        : 'Coordenadas no disponibles';

    final name = (j['nombreEspacio'] as String?)?.trim() ?? 'Sin nombre';
    final n = (j['semaforo'] as num?)?.toInt();

    return RunningSpace(
      espacioId: (j['espacio_id'] as num?)?.toInt(),
      corredorId: (j['corredor_id'] as num?)?.toInt(),
      title: name,
      link: (link?.isEmpty == true) ? null : link,
      coordinates: coordsText,
      imagePath: _assetForSpaceTitle(name),
      safety: _safetyFromDb(n),
    );
  }
}

// ====== HELPERS de coordenadas ======
bool _isLikelyUrl(String s) => s.startsWith('http://') || s.startsWith('https://');

(String, String)? _parseLatLngFromLinkOrText(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;

  final plain = RegExp(r'^\s*(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)\s*$');
  final mPlain = plain.firstMatch(text);
  if (mPlain != null) return (mPlain.group(1)!, mPlain.group(2)!);

  final geo = RegExp(r'^geo:\s*(-?\d{1,3}(?:\.\d+)?),\s*(-?\d{1,3}(?:\.\d+)?)');
  final mGeo = geo.firstMatch(text);
  if (mGeo != null) return (mGeo.group(1)!, mGeo.group(2)!);

  if (_isLikelyUrl(text)) {
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

    final s = text;

    final at = RegExp(r'@(-?\d{1,3}(?:\.\d+)?),\s*(-?\d{1,3}(?:\.\d+)?)');
    final mAt = at.firstMatch(s);
    if (mAt != null) return (mAt.group(1)!, mAt.group(2)!);

    final bang = RegExp(r'!3d(-?\d{1,3}(?:\.\d+)?)!4d(-?\d{1,3}(?:\.\d+)?)');
    final mBang = bang.firstMatch(s);
    if (mBang != null) return (mBang.group(1)!, mBang.group(2)!);
  }

  return null;
}

String _canonicalGoogleMapsUrlFromLatLng(String lat, String lng) =>
    'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

Future<(String, String)?> _resolveLatLngFromAnyLink(String raw) async {
  final direct = _parseLatLngFromLinkOrText(raw);
  if (direct != null) return direct;
  if (!_isLikelyUrl(raw)) return null;

  final client = http.Client();
  try {
    Uri current = Uri.parse(raw);

    for (int i = 0; i < 6; i++) {
      final req = http.Request('GET', current);
      req.followRedirects = false;
      req.headers['User-Agent'] = 'Mozilla/5.0 (Flutter; Dart)';

      final streamed = await client.send(req);
      final status = streamed.statusCode;

      final parsedHere = _parseLatLngFromLinkOrText(current.toString());
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
        final parsedMeta = _parseLatLngFromLinkOrText(redirected.toString());
        if (parsedMeta != null) return parsedMeta;

        final inner2 = redirected.queryParameters['link'];
        if (inner2 != null && inner2.isNotEmpty) {
          final innerUri = Uri.parse(Uri.decodeFull(inner2));
          final parsedInner = _parseLatLngFromLinkOrText(innerUri.toString());
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
  State<VistaEspacios> createState() => _VistaEspaciosState();
}

class _VistaEspaciosState extends State<VistaEspacios> {
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

  // ===== Notas: API =====
  Future<List<SpaceNote>> _fetchNotesForSpace(int espacioId) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse('$_baseUrl/espacios/$espacioId/notas');
      final resp = await http.get(url, headers: headers);
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        return list.map((e) => SpaceNote.fromApi(e as Map<String, dynamic>)).toList();
      } else {
        _showSnack('No se pudieron cargar notas (HTTP ${resp.statusCode}).', isError: true);
      }
    } catch (e) {
      _showSnack('Error al obtener notas: $e', isError: true);
    }
    return <SpaceNote>[];
  }

  Future<SpaceNote?> _createNoteApi(int espacioId, String content) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse('$_baseUrl/espacios/$espacioId/notas');
      final resp = await http.post(url, headers: headers, body: jsonEncode({'contenido': content}));
      if (resp.statusCode == 201) {
        return SpaceNote.fromApi(jsonDecode(resp.body) as Map<String, dynamic>);
      } else if (resp.statusCode == 409) {
        _showSnack('Límite de 5 notas alcanzado para este espacio.', isError: true);
      } else {
        _showSnack('No se pudo crear la nota (HTTP ${resp.statusCode}).', isError: true);
      }
    } catch (e) {
      _showSnack('Error al crear nota: $e', isError: true);
    }
    return null;
  }

  Future<bool> _updateNoteApi(int espacioId, SpaceNote note) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse('$_baseUrl/espacios/$espacioId/notas/${note.id}');
      final resp = await http.put(url, headers: headers, body: jsonEncode(note.toApiUpdate()));
      if (resp.statusCode == 200) return true;
      _showSnack('No se pudo actualizar la nota (HTTP ${resp.statusCode}).', isError: true);
    } catch (e) {
      _showSnack('Error al actualizar nota: $e', isError: true);
    }
    return false;
  }

  Future<bool> _deleteNoteApi(int espacioId, int notaId) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse('$_baseUrl/espacios/$espacioId/notas/$notaId');
      final resp = await http.delete(url, headers: headers);
      if (resp.statusCode == 200) return true;
      _showSnack('No se pudo eliminar la nota (HTTP ${resp.statusCode}).', isError: true);
    } catch (e) {
      _showSnack('Error al eliminar nota: $e', isError: true);
    }
    return false;
  }

  // ===== Espacios: listar/crear =====
  Future<void> _fetchSpaces() async {
    setState(() => _loading = true);
    try {
      final headers = await _authHeaders();
      final url = Uri.parse('$_baseUrl/espacios');
      final resp = await http.get(url, headers: headers);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        final items = data.map((e) => RunningSpace.fromJson(e as Map<String, dynamic>)).toList();

        setState(() {
          _apiSpaces
            ..clear()
            ..addAll(items);
        });

        await Future.wait(_apiSpaces.where((s) => s.espacioId != null).map((s) async {
          final notes = await _fetchNotesForSpace(s.espacioId!);
          setState(() => s.notes = notes);
        }));
      } else {
        _showSnack('No se pudo obtener la lista de espacios (HTTP ${resp.statusCode}).', isError: true);
      }
    } catch (e) {
      _showSnack('Error al obtener espacios: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addSpace(String name, String? link) async {
    final nameTrim = name.trim();
    final linkTrim = (link ?? '').trim();

    if (nameTrim.isEmpty) {
      _showSnack('El nombre es obligatorio.', isError: true);
      return;
    }
    if (linkTrim.isEmpty) {
      _showSnack('El link es obligatorio.', isError: true);
      return;
    }

    // No bloqueamos por validación de red: aceptamos maps.app.goo.gl tal cual.
    // Si el usuario pega "lat,lng", lo convertimos a URL canónica de Google Maps.
    final plain = _parseLatLngFromLinkOrText(linkTrim);
    final enlaceParaGuardar =
        (plain != null) ? _canonicalGoogleMapsUrlFromLatLng(plain.$1, plain.$2) : linkTrim;

    try {
      final headers = await _authHeaders();
      final url = Uri.parse('$_baseUrl/espacios');

      final body = jsonEncode({
        'nombreEspacio': nameTrim,
        'enlaceUbicacion': enlaceParaGuardar,
        // 'semaforo' opcional, no lo enviamos aquí
      });

      final resp = await http.post(url, headers: headers, body: body);
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;

        // Intentamos deducir coords SOLO para la pantalla de mapa; no se muestran en la lista.
        final parsedAfter = _parseLatLngFromLinkOrText(j['enlaceUbicacion'] as String? ?? '');
        final coordsText = (parsedAfter != null)
            ? 'Coordenadas: ${parsedAfter.$1}, ${parsedAfter.$2}'
            : 'Coordenadas no disponibles';

        final created = RunningSpace(
          espacioId: (j['espacio_id'] as num?)?.toInt(),
          corredorId: (j['corredor_id'] as num?)?.toInt(),
          title: (j['nombreEspacio'] as String?)?.trim() ?? 'Sin nombre',
          link: ((j['enlaceUbicacion'] as String?)?.trim().isEmpty ?? true)
              ? null
              : (j['enlaceUbicacion'] as String).trim(),
          coordinates: coordsText,
          imagePath: _assetForSpaceTitle((j['nombreEspacio'] as String?)?.trim() ?? ''),
        );

        setState(() {
          _apiSpaces.insert(0, created);
        });

        _showSnack('Espacio agregado.');
      } else if (resp.statusCode == 422) {
        _showSnack('Datos inválidos (422). Revisa nombre y enlace.', isError: true);
      } else {
        _showSnack('No se pudo crear el espacio (HTTP ${resp.statusCode}).', isError: true);
      }
    } catch (e) {
      _showSnack('Error al crear espacio: $e', isError: true);
    }
  }

  Future<void> _openOnMap(RunningSpace space) async {
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) {
      _showSnack('No hay conexión para mostrar el mapa.', isError: true);
      return;
    }

    String? lat;
    String? lng;

    if ((space.link ?? '').isNotEmpty) {
      final resolved = await _resolveLatLngFromAnyLink(space.link!.trim());
      if (resolved != null) {
        lat = resolved.$1;
        lng = resolved.$2;
      }
    }
    if (lat == null || lng == null) {
      final parsed = _parseLatLngFromLinkOrText(space.coordinates.replaceFirst('Coordenadas:', '').trim());
      if (parsed != null) {
        lat = parsed.$1;
        lng = parsed.$2;
      }
    }
    if (lat == null || lng == null) {
      _showSnack('No se pudieron resolver coordenadas de este link.', isError: true);
      return;
    }

    final routeCoords = 'Coordenadas: $lat, $lng';

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
          child: _AddSpaceSheet(onAddSpace: _addSpace),
        );
      },
    );
  }

  void _showAddNoteModal(RunningSpace space) {
    if (space.espacioId == null) {
      _showSnack('Para agregar notas, primero guarda este espacio en tu cuenta.', isError: true);
      return;
    }
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _AddNoteSheet(
            onSave: (newNote) async {
              final trimmed = newNote.trim();
              if (trimmed.isEmpty) {
                _showSnack('La nota no puede estar vacía.', isError: true);
                return;
              }
              final created = await _createNoteApi(space.espacioId!, trimmed);
              if (created != null) {
                setState(() => space.notes.add(created));
                _showSnack('Nota agregada.');
              }
            },
          ),
        );
      },
    );
  }

  void _showEditNoteModal(RunningSpace space, int noteIndex) {
    if (space.espacioId == null) return;
    final note = space.notes[noteIndex];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: _AddNoteSheet(
            initialNote: note.content,
            onSave: (edited) async {
              final trimmed = edited.trim();
              if (trimmed.isEmpty) {
                _showSnack('La nota no puede estar vacía.', isError: true);
                return;
              }
              final backup = note.content;
              setState(() => note.content = trimmed);
              final ok = await _updateNoteApi(space.espacioId!, note);
              if (ok) {
                _showSnack('Nota actualizada.');
              } else {
                setState(() => note.content = backup);
              }
            },
          ),
        );
      },
    );
  }

  void _deleteNote(RunningSpace space, int noteIndex) async {
    if (space.espacioId == null) return;
    final note = space.notes[noteIndex];
    final ok = await _deleteNoteApi(space.espacioId!, note.id);
    if (ok) {
      setState(() => space.notes.removeAt(noteIndex));
      _showSnack('Nota eliminada.');
    }
  }

  Future<bool> _updateSafetyApi(int espacioId, SpaceSafety newSafety) async {
    try {
      final headers = await _authHeaders();
      final n = () {
        switch (newSafety) {
          case SpaceSafety.unsafe:
            return 0;
          case SpaceSafety.partiallySafe:
            return 1;
          case SpaceSafety.safe:
            return 2;
          case SpaceSafety.none:
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

  void _updateSafety(RunningSpace space, SpaceSafety newSafety) async {
    if (space.espacioId == null) {
      _showSnack('Primero guarda este espacio en tu cuenta para poder calificarlo.', isError: true);
      return;
    }
    final prev = space.safety;
    setState(() => space.safety = newSafety); // actualización optimista
    final ok = await _updateSafetyApi(space.espacioId!, newSafety);
    if (!ok) {
      setState(() => space.safety = prev); // revertir si falló
      _showSnack('No se pudo actualizar el semáforo. Intenta de nuevo.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final combined = _apiSpaces; // solo API

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
                      combined.isEmpty ? 'Sin espacios' : '${combined.length} espacio(s)',
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
        _linkController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
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
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
                labelText: 'Link del espacio *',
                hintText: 'https://maps.app.goo.gl/… o https://maps.google.com/… o lat,lng',
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Ingresa un link.' : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
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
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
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

// --- CARD de espacio ---
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
                  child: Icon(Icons.image_not_supported, color: Colors.white54, size: 50),
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
                // 👇 Ya no mostramos las coordenadas en la tarjeta
                if (space.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: space.notes.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final SpaceNote note = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Colors.grey)),
                            Expanded(
                              child: Text(
                                note.content,
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

// --- SLIDER del semáforo (UI local) ---
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

class _GradientRectSliderTrackShape extends SliderTrackShape with BaseSliderTrackShape {
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
      RRect.fromRectAndRadius(trackRect, Radius.circular(trackRect.height / 2)),
      paint,
    );
  }
}