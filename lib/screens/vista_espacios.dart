import 'package:chita_app/screens/map_detail.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // Importamos para usar los colores

// --- MODELO DE DATOS ---
class RunningSpace {
  final String imagePath;
  final String title;
  final String mapImagePath;
  final String coordinates;
  final String? link;

  RunningSpace({
    required this.imagePath,
    required this.title,
    required this.mapImagePath,
    required this.coordinates,
    this.link,
  });
}

class VistaEspacios extends StatefulWidget {
  const VistaEspacios({super.key});

  @override
  State<VistaEspacios> createState() => _VistaEspaciosState();
}

class _VistaEspaciosState extends State<VistaEspacios> {
  // --- LISTA DE ESPACIOS ---
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
    ),
    RunningSpace(
      imagePath: 'assets/La_purisima.jpg',
      title: 'La Purísima',
      mapImagePath: 'assets/map.png',
      coordinates: 'Coordenadas: 22.7496541, -102.5238082',
    ),
    RunningSpace(
      imagePath: 'assets/ramon.jpg',
      title: 'Parque Ramón López Velarde',
      mapImagePath: 'assets/map.png',
      coordinates: 'Coordenadas: 22.7582581, -102.5417730',
    ),
    RunningSpace(
      imagePath: 'assets/plata.jpg',
      title: 'Parque Arroyo de la Plata',
      mapImagePath: 'assets/map.png',
      coordinates: 'Coordenadas: 22.7569926, -102.5387186',
    ),
    RunningSpace(
      imagePath: 'assets/Peñuela.jpg',
      title: 'Parque la Peñuela',
      mapImagePath: 'assets/map.png',
      coordinates: 'Coordenadas: 22.7712755, -102.5655441',
    ),
    RunningSpace(
      imagePath: 'assets/Ecoparque.jpg',
      title: 'Ecoparque',
      mapImagePath: 'assets/map.png',
      coordinates: 'Coordenadas: 22.7815430, -102.5455093',
    ),
    RunningSpace(
      imagePath: 'assets/poli.jpg',
      title: 'Polideportivo',
      mapImagePath: 'assets/map.png',
      coordinates: 'Coordenadas: 22.7582896, -102.5660751',
    ),
    RunningSpace(
      imagePath: 'assets/Estadio.jpg',
      title: 'Estadio',
      mapImagePath: 'assets/map.png',
      coordinates: 'Coordenadas: 22.7668222, -102.5492993',
    ),
    RunningSpace(
      imagePath: 'assets/Luis.jpg',
      title: 'Parque Luis Donaldo Colosio',
      mapImagePath: 'assets/map.png',
      coordinates: 'Coordenadas: 22.7672321, -102.5977192',
    ),
  ];

  // --- 1. FUNCIÓN PARA AÑADIR UN ESPACIO ---
  // Esta función se pasará al modal para que pueda actualizar la lista.
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

  // --- 2. FUNCIÓN PARA MOSTRAR EL MODAL BOTTOM SHEET ---
  void _showAddSpaceModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que el modal ocupe más altura
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          // Padding para que el teclado no cubra el modal
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _AddSpaceSheet(
            onAddSpace: _addSpace, // Pasamos la función como callback
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                100,
              ), // Espacio para el botón
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
                          imagePath: space.imagePath,
                          title: space.title,
                          mapImagePath: space.mapImagePath,
                          coordinates: space.coordinates,
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
                // --- 3. ACTUALIZAMOS EL BOTÓN PARA LLAMAR AL MODAL ---
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

// --- 4. WIDGET PARA EL FORMULARIO DEL BOTTOM SHEET ---
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
        _linkController.text.trim(),
      );
      Navigator.of(context).pop(); // Cierra el modal
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: cardColor, // Usando el color de las tarjetas
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
            _buildTextField(
              controller: _nameController,
              label: 'Nombre del espacio *',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Por favor, ingresa un nombre.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _linkController,
              label: 'Link del espacio (opcional)',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _submit,
                child: const Text(
                  'Agregar Espacio',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper para construir los campos de texto con el estilo deseado
  Widget _buildTextField({
    required String label,
    TextEditingController? controller,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[850],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor),
        ),
        errorBorder: OutlineInputBorder(
          // Borde para el estado de error
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          // Borde para el estado de error con foco
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
      ),
    );
  }
}

// --- WIDGET DE TARJETA (SIN CAMBIOS) ---
class _RouteCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final String mapImagePath;
  final String coordinates;

  const _RouteCard({
    required this.imagePath,
    required this.title,
    required this.mapImagePath,
    required this.coordinates,
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
            imagePath,
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
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapDetailScreen(
                            routeTitle: title,
                            routeCoordinates: coordinates,
                            mapImagePath: mapImagePath,
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
