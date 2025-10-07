import 'package:flutter/material.dart';
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
          child: _AddContactSheet(),
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
                'Contactos de Emergencia',
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
                    Icons.phone,
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
                    'Agrega contactos de emergencia para recibir\nalertas cuando necesites ayuda',
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

// Widget para el BottomSheet de agregar contacto (sin cambios)
class _AddContactSheet extends StatelessWidget {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Agregar Contacto de Emergencia',
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
          _buildTextField(label: 'Número de Teléfono *'),
          const SizedBox(height: 16),
          _buildTextField(label: 'Email (opcional)'),
          const SizedBox(height: 16),
          _buildTextField(label: 'Relación (opcional)'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Lógica para agregar contacto
                Navigator.of(context).pop();
              },
              child: const Text('Agregar Contacto'),
            ),
          ),
        ],
      ),
    );
  }

  // Helper para construir los campos de texto con el estilo deseado
  Widget _buildTextField({required String label}) {
    return TextField(
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
      ),
    );
  }
}