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
    this.link,
    this.espacioId,
    this.corredorId,
    this.esInicial = false,
    this.imagePath = 'assets/placeholder.jpg',
    this.mapImagePath = 'assets/map.png',
    String? coordinates,
    this.safety = SpaceSafety.none,
    List<String>? notes,
  })  : coordinates = coordinates ??
            (link == null || link.isEmpty
                ? 'Coordenadas no disponibles'
                : 'Link: $link'),
        notes = notes ?? [];

  // Factory desde JSON del API
  factory RunningSpace.fromJson(Map<String, dynamic> j) {
    final link = (j['enlaceUbicacion'] as String?)?.trim();
    return RunningSpace(
      espacioId: (j['espacio_id'] as num?)?.toInt(),
      corredorId: (j['corredor_id'] as num?)?.toInt(),
      esInicial: (j['es_inicial'] as bool?) ?? false,
      title: (j['nombreEspacio'] as String?)?.trim() ?? 'Sin nombre',
      link: link?.isEmpty == true ? null : link,
      coordinates: (link == null || link.isEmpty)
          ? 'Coordenadas no disponibles'
          : 'Link: $link',
    );
  }

  // Para POST (crear)
  Map<String, dynamic> toCreateBody() => {
        'nombreEspacio': title,
        'enlaceUbicacion': link ?? '',
        'es_inicial': false,
      };
}

class VistaEspacios extends StatefulWidget {
  const VistaEspacios({super.key});

  @override
  State<VistaEspacios> createState() => _VistaEspaciosState();
}

class _VistaEspaciosState extends State<VistaEspacios> {
  final List<RunningSpace> _spaces = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchSpaces();
  }

  Future<Map<String, String>> _authHeaders() async {
    // Ajusta estos métodos a los que tengas en tu SessionRepository
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
          _spaces
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

  bool _isValidLink(String? link) {
    if (link == null || link.trim().isEmpty) return true; // opcional
    final l = link.trim();
    // Aceptamos http/https y/o links de Google Maps simples
    final uriOk = l.startsWith('http://') || l.startsWith('https://');
    // O también lat,lng (números) como texto suelto
    final latLngRe = RegExp(r'^\s*-?\d{1,3}\.\d+,\s*-?\d{1,3}\.\d+\s*$');
    return uriOk || latLngRe.hasMatch(l);
  }

  Future<void> _addSpace(String name, String? link) async {
    // Validaciones del CU (6A y 7A)
    if (name.trim().isEmpty) {
      _showSnack('El nombre es obligatorio.', isError: true);
      return;
    }
    if (!_isValidLink(link)) {
      _showSnack('El enlace no parece válido. Corrígelo, por favor.', isError: true);
      return;
    }

    try {
      final headers = await _authHeaders();
      final url = Uri.parse('$_baseUrl/espacios');
      final body = jsonEncode({
        'nombreEspacio': name.trim(),
        'enlaceUbicacion': (link ?? '').trim(),
        'es_inicial': false,
      });

      final resp = await http.post(url, headers: headers, body: body);
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        final created = RunningSpace.fromJson(j);

        setState(() {
          _spaces.insert(0, created);
        });

        _showSnack('Espacio agregado.');
      } else if (resp.statusCode == 422) {
        _showSnack('Datos inválidos (422). Revisa nombre y enlace.', isError: true);
      } else {
        _showSnack('No se pudo crear el espacio (HTTP ${resp.statusCode}).',
            isError: true);
      }
    } catch (e) {
      _showSnack('Error al crear espacio: $e', isError: true);
    }
  }

  Future<void> _openOnMap(RunningSpace space) async {
    // 7A Falta de conectividad
    final conn = await Connectivity().checkConnectivity();
    if (conn == ConnectivityResult.none) {
      _showSnack('No hay conexión a internet para mostrar el mapa.', isError: true);
      return;
    }

    // 3A Selección inválida (sin ubicación utilizable)
    final hasAnyLocation =
        (space.link != null && space.link!.trim().isNotEmpty) ||
            (space.coordinates.toLowerCase().contains('coordenadas'));

    if (!hasAnyLocation) {
      _showSnack('Este espacio no tiene una ubicación válida.', isError: true);
      return;
    }

    // Navega a tu pantalla de mapa (se mantiene tu implementación)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapDetailScreen(
          routeTitle: space.title,
          // Mostramos el texto de coordinates; si deseas cambiar a usar el link,
          // ajusta MapDetailScreen (otro CU).
          routeCoordinates: space.coordinates,
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

  // --- FUNCIÓN MODIFICADA: límite de 5 notas (UI local, no persiste en este CU) ---
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
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (_loading)
              const LinearProgressIndicator(minHeight: 2),
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
                      _spaces.isEmpty ? 'Sin espacios' : '${_spaces.length} espacio(s)',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._spaces
                    // Si quieres mostrar máximo 10 (punto 2 del flujo),
                    // comenta la línea de abajo si prefieres todos:
                    .take(10)
                    .map(
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
                    )
                    .toList(),
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