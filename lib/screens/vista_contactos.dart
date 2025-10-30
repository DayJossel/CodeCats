import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class VistaContactos extends StatefulWidget {
  const VistaContactos({super.key});

  @override
  State<VistaContactos> createState() => _VistaContactosState();
}

class _VistaContactosState extends State<VistaContactos> {
  List<dynamic> _contactos = [];
  bool _isLoading = false;
  int? corredorId;
  String? contrasenia;
  bool _isUserLoaded = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    corredorId = prefs.getInt('corredor_id');
    contrasenia = prefs.getString('contrasenia');

    setState(() => _isUserLoaded = true);

    if (corredorId != null && contrasenia != null) {
      _fetchContactos();
    }
  }

  Future<void> _fetchContactos() async {
    if (corredorId == null || contrasenia == null) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('http://157.137.187.110:8000/contactos'),
        headers: {
          'X-Corredor-Id': '$corredorId',
          'X-Contrasenia': contrasenia!,
        },
      );
      if (response.statusCode == 200) {
        setState(() {
          _contactos = jsonDecode(response.body);
        });
      } else {
        _showSnack('Error al obtener contactos (${response.statusCode})');
      }
    } catch (e) {
      _showSnack('Error de conexión: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteContacto(int contactoId) async {
    try {
      final response = await http.delete(
        Uri.parse('http://157.137.187.110:8000/contactos/$contactoId'),
        headers: {
          'X-Corredor-Id': '$corredorId',
          'X-Contrasenia': contrasenia!,
        },
      );
      if (response.statusCode == 200) {
        _showSnack('Contacto eliminado correctamente');
        _fetchContactos();
      } else {
        _showSnack('Error al eliminar (${response.statusCode})');
      }
    } catch (e) {
      _showSnack('Error: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showAddContactModal({Map<String, dynamic>? contacto}) {
    if (!_isUserLoaded || corredorId == null || contrasenia == null) {
      _showSnack(
        'Espera a que se cargue tu sesión antes de agregar contactos.',
      );
      return;
    }

    // 🔒 Límite de 5 contactos
    if (contacto == null && _contactos.length >= 5) {
      _showSnack('Solo puedes registrar hasta 5 contactos de confianza.');
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
          child: _AddContactSheet(
            contacto: contacto,
            corredorId: corredorId!,
            contrasenia: contrasenia!,
            onSave: _fetchContactos,
            totalContactos: _contactos.length,
          ),
        );
      },
    );
  }

  void _confirmDelete(int contactoId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar contacto"),
        content: const Text(
          "¿Seguro que deseas eliminar este contacto de confianza?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteContacto(contactoId);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUserLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _contactos.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _fetchContactos,
              color: primaryColor,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _contactos.length,
                itemBuilder: (context, index) {
                  final c = _contactos[index];
                  return Card(
                    color: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: primaryColor,
                        child: Icon(Icons.person, color: Colors.black),
                      ),
                      title: Text(c['nombre']),
                      subtitle: Text("${c['relacion']} • ${c['telefono']}"),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showAddContactModal(contacto: c);
                          } else if (value == 'delete') {
                            _confirmDelete(c['contacto_id']);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Editar'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Eliminar'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: () {
          if (_contactos.length >= 5) {
            _showSnack('Solo puedes registrar hasta 5 contactos de confianza.');
          } else {
            _showAddContactModal();
          }
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.phone_in_talk, color: Colors.grey[600], size: 60),
          const SizedBox(height: 20),
          const Text(
            'No hay contactos agregados',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Agrega contactos de confianza para recibir alertas\ncuando necesites ayuda',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// FORMULARIO DE AGREGAR / EDITAR CONTACTO
// -------------------------------------------------------------
class _AddContactSheet extends StatefulWidget {
  final Map<String, dynamic>? contacto;
  final int corredorId;
  final String contrasenia;
  final VoidCallback onSave;
  final int totalContactos;

  const _AddContactSheet({
    this.contacto,
    required this.corredorId,
    required this.contrasenia,
    required this.onSave,
    required this.totalContactos,
  });

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final nombreController = TextEditingController();
  final telefonoController = TextEditingController();
  final relacionController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.contacto != null) {
      nombreController.text = widget.contacto!['nombre'] ?? '';
      telefonoController.text = widget.contacto!['telefono'] ?? '';
      relacionController.text = widget.contacto!['relacion'] ?? '';
    }
  }

  Future<void> _guardarContacto() async {
    if (widget.contacto == null && widget.totalContactos >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo puedes tener hasta 5 contactos.')),
      );
      Navigator.of(context).pop();
      return;
    }

    final nombre = nombreController.text.trim();
    final telefonoRaw = telefonoController.text.trim();
    final relacion = relacionController.text.trim();

    if (nombre.isEmpty || telefonoRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena los campos obligatorios')),
      );
      return;
    }

    // --- Normaliza el teléfono a solo dígitos ---
    String telefonoDigits = telefonoRaw.replaceAll(RegExp(r'\D'), '');
    // Casos comunes en MX: +52XXXXXXXXXX, 52XXXXXXXXXX, 521XXXXXXXXXX (WhatsApp)
    if (telefonoDigits.length == 13 && telefonoDigits.startsWith('521')) {
      telefonoDigits = telefonoDigits.substring(3);
    } else if (telefonoDigits.length == 12 && telefonoDigits.startsWith('52')) {
      telefonoDigits = telefonoDigits.substring(2);
    }

    // Validación estricta: exactamente 10 dígitos
    if (telefonoDigits.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El teléfono debe tener exactamente 10 dígitos.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final body = {
      'nombre': nombre,
      'telefono': telefonoDigits, // <- usa el número normalizado
      'relacion': relacion.isEmpty ? 'N/A' : relacion,
    };

    final url = widget.contacto == null
        ? Uri.parse('http://157.137.187.110:8000/contactos')
        : Uri.parse('http://157.137.187.110:8000/contactos/${widget.contacto!['contacto_id']}');

    final method = widget.contacto == null ? 'POST' : 'PUT';

    try {
      final response = await (method == 'POST'
          ? http.post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'X-Corredor-Id': '${widget.corredorId}',
                'X-Contrasenia': widget.contrasenia,
              },
              body: jsonEncode(body),
            )
          : http.put(
              url,
              headers: {
                'Content-Type': 'application/json',
                'X-Corredor-Id': '${widget.corredorId}',
                'X-Contrasenia': widget.contrasenia,
              },
              body: jsonEncode(body),
            ));

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.of(context).pop();
        widget.onSave();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error (${response.statusCode}): ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.contacto == null
                    ? 'Agregar Contacto'
                    : 'Editar Contacto',
                style: const TextStyle(
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
          _buildTextField('Nombre *', nombreController),
          const SizedBox(height: 16),
          _buildTextField(
            'Teléfono *',
            telefonoController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          _buildTextField('Relación (opcional)', relacionController),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _guardarContacto,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text(
                      'Guardar',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: primaryColor),
        ),
      ),
    );
  }
}
