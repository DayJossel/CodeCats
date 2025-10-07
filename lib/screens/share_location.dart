import 'package:flutter/material.dart';
import '../main.dart'; // Para los colores

// Modelo simple para representar un contacto
class Contact {
  final String name;
  final String phone;
  final String initials;

  Contact({required this.name, required this.phone, required this.initials});
}

class ShareLocationScreen extends StatefulWidget {
  const ShareLocationScreen({super.key});

  @override
  State<ShareLocationScreen> createState() => _ShareLocationScreenState();
}

class _ShareLocationScreenState extends State<ShareLocationScreen> {
  // Lista de contactos de ejemplo
  final List<Contact> _contacts = [
    Contact(name: 'María González', phone: '+52 555 123 4567', initials: 'M'),
    Contact(name: 'Carlos Rodríguez', phone: '+52 555 234 5678', initials: 'C'),
    Contact(name: 'Ana Martínez', phone: '+52 555 345 6789', initials: 'A'),
    Contact(name: 'Pedro Sánchez', phone: '+52 555 456 7890', initials: 'P'),
    Contact(name: 'Laura Torres', phone: '+52 555 567 8901', initials: 'L'),
  ];

  // Lista para guardar los contactos seleccionados
  final Set<Contact> _selectedContacts = {};

  void _onContactTap(Contact contact) {
    setState(() {
      if (_selectedContacts.contains(contact)) {
        _selectedContacts.remove(contact);
      } else {
        _selectedContacts.add(contact);
      }
    });
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => _ConfirmationDialog(
        selectedContacts: _selectedContacts.toList(),
        onConfirm: () {
          Navigator.of(context).pop(); // Cierra el diálogo de confirmación
          _showSuccessDialog();
        },
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => _SuccessDialog(
        selectedContacts: _selectedContacts.toList(),
        onDone: () {
           // Cierra el dialogo de exito y la pantalla de compartir
          Navigator.of(context).pop(); 
          Navigator.of(context).pop();
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final bool canContinue = _selectedContacts.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compartir Ubicación'),
        backgroundColor: backgroundColor,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selecciona contactos',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Elige con quién compartir tu ubicación',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                final isSelected = _selectedContacts.contains(contact);
                return _ContactTile(
                  contact: contact,
                  isSelected: isSelected,
                  onTap: () => _onContactTap(contact),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canContinue ? _showConfirmationDialog : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  disabledBackgroundColor: Colors.grey[800],
                ),
                child: Text(
                  canContinue
                      ? 'Continuar (${_selectedContacts.length})'
                      : 'Continuar',
                  style: TextStyle(
                    color: canContinue ? Colors.black : Colors.grey[600]
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget para cada fila de contacto
class _ContactTile extends StatelessWidget {
  final Contact contact;
  final bool isSelected;
  final VoidCallback onTap;

  const _ContactTile({
    required this.contact,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: primaryColor,
        child: Text(contact.initials, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      title: Text(contact.name, style: const TextStyle(color: Colors.white)),
      subtitle: Text(contact.phone, style: const TextStyle(color: Colors.grey)),
      trailing: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? primaryColor : Colors.transparent,
          border: Border.all(color: isSelected ? primaryColor : Colors.grey),
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.black, size: 16)
            : null,
      ),
    );
  }
}

// Diálogo de confirmación de tiempo
class _ConfirmationDialog extends StatefulWidget {
  final List<Contact> selectedContacts;
  final VoidCallback onConfirm;

  const _ConfirmationDialog({required this.selectedContacts, required this.onConfirm});

  @override
  State<_ConfirmationDialog> createState() => _ConfirmationDialogState();
}

class _ConfirmationDialogState extends State<_ConfirmationDialog> {
  String _selectedFrequency = '10 min';
  String _selectedDuration = '1h';
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Confirmar compartir', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Quieres compartir tu ubicación con los contactos seleccionados?'),
          const SizedBox(height: 20),
          const Text('Frecuencia de actualización', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['10 min', '30 min', '1 hora'].map((freq) {
              final isSelected = _selectedFrequency == freq;
              return ChoiceChip(
                label: Text(freq),
                selected: isSelected,
                onSelected: (selected) {
                  if(selected) setState(() => _selectedFrequency = freq);
                },
                backgroundColor: Colors.grey[800],
                selectedColor: primaryColor,
                labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Duración de la sesión', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['1h', '2h', '3h', '4h', '5h'].map((duration) {
               final isSelected = _selectedDuration == duration;
              return ChoiceChip(
                label: Text(duration),
                selected: isSelected,
                onSelected: (selected) {
                   if(selected) setState(() => _selectedDuration = duration);
                },
                backgroundColor: Colors.grey[800],
                selectedColor: primaryColor,
                labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: widget.onConfirm,
                child: const Text('Compartir'),
              ),
            ),
          ],
        )
      ],
    );
  }
}

// Diálogo de éxito
class _SuccessDialog extends StatelessWidget {
    final List<Contact> selectedContacts;
    final VoidCallback onDone;

    const _SuccessDialog({required this.selectedContacts, required this.onDone});


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.green,
            child: Icon(Icons.check, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 20),
          const Text('¡Ubicación compartida!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Tu ubicación se ha compartido exitosamente con:'),
          const SizedBox(height: 16),
          ...selectedContacts.map((c) => Text('• ${c.name}')).toList(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              child: const Text('Entendido')
            ),
          ),
        ],
      ),
    );
  }
}
