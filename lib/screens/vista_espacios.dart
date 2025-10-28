import 'package:chita_app/screens/map_detail.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // Importamos para usar los colores

// --- NUEVO ENUM PARA EL SISTEMA DE 3 PUNTOS ---
enum SpaceSafety { none, unsafe, partiallySafe, safe }

// --- MODELO DE DATOS ACTUALIZADO ---
class RunningSpace {
  final String imagePath;
  final String title;
  final String mapImagePath;
  final String coordinates;
  final String? link;
  // --- CAMBIO: Se usa el nuevo enum en lugar del score ---
  SpaceSafety safety;
  List<String> notes;

  RunningSpace({
    required this.imagePath,
    required this.title,
    required this.mapImagePath,
    required this.coordinates,
    this.link,
    this.safety = SpaceSafety.none, // Valor por defecto
    List<String>? notes,
  }) : notes = notes ?? [];
}


class VistaEspacios extends StatefulWidget {
  const VistaEspacios({super.key});

  @override
  State<VistaEspacios> createState() => _VistaEspaciosState();
}

class _VistaEspaciosState extends State<VistaEspacios> {
  final List<RunningSpace> _spaces = [
    RunningSpace(
      imagePath: 'assets/parque_la_encantada.jpg',
      title: 'Parque La Encantada',
      mapImagePath: 'assets/map.png',
      coordinates: 'Coordenadas: 22.7597523, -102.5788378',
    ),
    RunningSpace(
      imagePath: 'assets/parque_sierra_de_alica.jpg',
      title: 'Parque Sierra de Álica',
      mapImagePath: 'assets/map.png',
      coordinates: 'Coordenadas: 22.7696141, -102.5767151',
      safety: SpaceSafety.safe,
    ),
    RunningSpace(
      imagePath: 'assets/La_purisima.jpg',
      title: 'La Purísima',
      mapImagePath: 'assets/map.png',
      coordinates: 'Coordenadas: 22.7496541, -102.5238082',
      safety: SpaceSafety.partiallySafe,
    ),
    RunningSpace(
      imagePath: 'assets/ramon.jpg',
      title: 'Parque Ramón López Velarde',
      mapImagePath: 'assets/map.png',
      coordinates: 'Coordenadas: 22.7582581, -102.5417730',
      safety: SpaceSafety.unsafe,
    ),
    RunningSpace(
      imagePath: 'assets/plata.jpg',
      title: 'Parque Arroyo de la Plata',
      mapImagePath: 'assets/map.png',
      coordinates: 'Coordenadas: 22.7569926, -102.5387186',
    ),
  ];

  void _addSpace(String name, String? link) {
    setState(() {
      _spaces.add(
        RunningSpace(
          imagePath: 'assets/placeholder.jpg',
          title: name,
          mapImagePath: 'assets/map.png',
          coordinates: 'Coordenadas no disponibles',
          link: link,
        ),
      );
    });
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

  // --- FUNCIÓN MODIFICADA CON EL LÍMITE DE NOTAS ---
  void _showAddNoteModal(RunningSpace space) {
    // Verifica si ya se alcanzó el límite de 5 notas.
    if (space.notes.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puedes agregar más de 5 notas por espacio.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return; // Detiene la ejecución para no mostrar el modal.
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
      space.safety = newSafety;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
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
                const SizedBox(height: 20),
                ..._spaces
                    .map(
                      (space) => Padding(
                        padding: const EdgeInsets.only(bottom: 20.0),
                        child: _RouteCard(
                          space: space,
                          onAddNote: () => _showAddNoteModal(space),
                          onDeleteNote: (index) => _deleteNote(space, index),
                          onEditNote: (index) => _showEditNoteModal(space, index),
                          onSafetyChanged: (newSafety) => _updateSafety(space, newSafety),
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

// --- WIDGET PARA AGREGAR NUEVO ESPACIO (Sin cambios) ---
class _AddSpaceSheet extends StatefulWidget {
  final Function(String name, String? link) onAddSpace;
  const _AddSpaceSheet({required this.onAddSpace});

  @override
  State<_AddSpaceSheet> createState() => _AddSpaceSheetState();
}

class _AddSpaceSheetState extends State<_AddSpaceSheet> {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController();
    final _linkController = TextEditingController();

    @override
    void dispose() {
        _nameController.dispose();
        _linkController.dispose();
        super.dispose();
    }

    void _submit() {
        if (_formKey.currentState!.validate()) {
            widget.onAddSpace(
                _nameController.text.trim(),
                _linkController.text.trim().isEmpty ? null : _linkController.text.trim(),
            );
            Navigator.of(context).pop();
        }
    }

    @override
    Widget build(BuildContext context) {
        return Container(
            padding: const EdgeInsets.all(24.0),
            decoration: const BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
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
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                    ),
                                ),
                                IconButton(
                                    icon: const Icon(Icons.close, color: Colors.grey),
                                    onPressed: () => Navigator.of(context).pop(),
                                ),
                            ],
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(labelText: 'Nombre del espacio *'),
                            validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                    return 'Por favor, ingresa un nombre.';
                                }
                                return null;
                            },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: _linkController,
                            decoration: const InputDecoration(labelText: 'Link del espacio (opcional)'),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                                onPressed: _submit,
                                child: const Text('Agregar Espacio'),
                            ),
                        ),
                    ],
                ),
            ),
        );
    }
}


// --- WIDGET MODAL PARA AGREGAR/EDITAR NOTA (Sin cambios) ---
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
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
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
          const SizedBox(height: 20),
          TextField(
            controller: _noteController,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Escribe tus notas aquí...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
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

// --- WIDGET DE TARJETA (Sin cambios) ---
class _RouteCard extends StatelessWidget {
  final RunningSpace space;
  final VoidCallback onAddNote;
  final Function(int) onDeleteNote;
  final Function(int) onEditNote;
  final Function(SpaceSafety) onSafetyChanged;

  const _RouteCard({
    required this.space,
    required this.onAddNote,
    required this.onDeleteNote,
    required this.onEditNote,
    required this.onSafetyChanged,
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


                if (space.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: space.notes.asMap().entries.map((entry) {
                      int idx = entry.key;
                      String note = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: Colors.grey)),
                            Expanded(
                              child: Text(
                                note,
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapDetailScreen(
                            routeTitle: space.title,
                            routeCoordinates: space.coordinates,
                            mapImagePath: space.mapImagePath,
                          ),
                        ),
                      );
                    },
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

// --- WIDGET PERSONALIZADO PARA EL SLIDER DE 3 PUNTOS ---
class _SafetySlider extends StatelessWidget {
    final SpaceSafety safety;
    final Function(SpaceSafety) onChanged;

    const _SafetySlider({
        required this.safety,
        required this.onChanged,
    });

    // Mapea el enum a un valor numérico para el slider
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
                return 1.0; // Valor por defecto en el medio
        }
    }
    
    // Mapea el enum a una etiqueta de texto
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

    // Mapea el enum a un color
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
                            divisions: 2, // 3 puntos (0, 1, 2)
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


// --- WIDGET PARA PINTAR EL GRADIENTE (Sin cambios) ---
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