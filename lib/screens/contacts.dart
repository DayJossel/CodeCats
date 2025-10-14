import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Importado para el formateador de texto
import '../main.dart'; // Para los colores

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {

  void _showAddContactModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que el modal ocupe más altura
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          // Padding para que el teclado no cubra el modal
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: const _AddContactSheet(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            backgroundColor: backgroundColor,
            pinned: true,
            expandedHeight: 150.0,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: CircleAvatar(
                  backgroundColor: primaryColor,
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.black),
                    onPressed: _showAddContactModal,
                  ),
                ),
              ),
            ],
            flexibleSpace: const FlexibleSpaceBar(
              titlePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              title: Text(
                'Contactos de Confianza',
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: Colors.white
                ),
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone_in_talk,
                    color: Colors.grey[600],
                    size: 50,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No hay contactos agregados',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agrega contactos de confianza para recibir\nalertas cuando necesites ayuda',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget para el BottomSheet de agregar contacto
class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet();

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  // Lista de relaciones predefinidas
  final List<String> _relations = ['Mamá', 'Papá', 'Tío', 'Tía', 'Hermano', 'Hermana', 'Amigo', 'Otro'];
  
  // Variable para guardar la relación seleccionada
  String? _selectedRelation;
  
  // Controladores para los campos de texto
  final _otherRelationController = TextEditingController();
  final _relationDisplayController = TextEditingController(); // Para mostrar la relación seleccionada
  
  // Variable para controlar si se muestra el campo de texto de "Otro"
  bool _showOtherField = false;

  @override
  void dispose() {
    // Limpiar los controladores cuando el widget se destruye
    _otherRelationController.dispose();
    _relationDisplayController.dispose();
    super.dispose();
  }
  
  /// Muestra un modal con un selector de tipo "carrete" (ListWheelScrollView)
  void _showRelationPicker() {
    // Calcula el índice inicial para el carrete
    int initialIndex = _selectedRelation != null ? _relations.indexOf(_selectedRelation!) : 0;
    final scrollController = FixedExtentScrollController(initialItem: initialIndex);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2E), // Un color oscuro para el fondo del picker
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (BuildContext context) {
        int selectedIndex = initialIndex;
        return SizedBox(
          height: 260,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Seleccionar Relación", 
                      style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                    TextButton(
                      onPressed: () {
                        // Al presionar 'Hecho', se actualiza el estado y se cierra el modal
                        setState(() {
                          _selectedRelation = _relations[selectedIndex];
                          _relationDisplayController.text = _selectedRelation!;
                          _showOtherField = _selectedRelation == 'Otro';
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Hecho', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListWheelScrollView.useDelegate(
                  controller: scrollController,
                  itemExtent: 50,
                  perspective: 0.005,
                  diameterRatio: 1.5,
                  physics: const FixedExtentScrollPhysics(),
                  onSelectedItemChanged: (index) {
                    selectedIndex = index;
                  },
                  childDelegate: ListWheelChildListDelegate(
                    children: _relations.map((relation) => Center(
                      child: Text(
                        relation,
                        style: const TextStyle(color: Colors.white, fontSize: 22),
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Agregar Contacto de Confianza',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField(label: 'Nombre *'),
            const SizedBox(height: 16),
            // --- INICIO DE LA MODIFICACIÓN ---
            _buildTextField(
              label: 'Número de Teléfono *', 
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Solo permite números
            ),
            // --- FIN DE LA MODIFICACIÓN ---
            const SizedBox(height: 16),
            
            // Campo de Relación que abre el selector de carrete
            GestureDetector(
              onTap: _showRelationPicker,
              child: AbsorbPointer( // Evita que el TextField obtenga el foco y abra el teclado
                child: _buildTextField(
                  label: 'Relación (opcional)',
                  controller: _relationDisplayController,
                  suffixIcon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.grey, size: 28),
                ),
              ),
            ),
            
            // Campo de texto condicional para "Otro"
            if (_showOtherField)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: _buildTextField(
                  label: 'Especificar relación',
                  controller: _otherRelationController,
                ),
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
                  )
                ),
                onPressed: () {
                  // Lógica para agregar contacto
                  Navigator.of(context).pop();
                },
                child: const Text('Agregar Contacto', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper para construir los campos de texto
  // MODIFICADO: Acepta icono de sufijo y formateadores de entrada
  Widget _buildTextField({
    required String label, 
    TextEditingController? controller,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[850],
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor),
        ),
      ),
    );
  }
}

