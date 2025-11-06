// lib/screens/vista_contactos.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

const String _baseUrl = 'http://157.137.187.110:8000';

class VistaContactos extends StatefulWidget {
  const VistaContactos({super.key});

  @override
  State<VistaContactos> createState() => EstadoVistaContactos();
}

class EstadoVistaContactos extends State<VistaContactos> {
  List<Map<String, dynamic>> _contactos = [];
  bool _cargando = false;
  int? corredorId;
  String? contrasenia;
  bool _usuarioCargado = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    corredorId = prefs.getInt('corredor_id');
    contrasenia = prefs.getString('contrasenia');

    setState(() => _usuarioCargado = true);

    if (corredorId != null && contrasenia != null) {
      _listarContactos();
    }
  }

  Map<String, String> _encabezadosAuth() => {
        'X-Corredor-Id': '${corredorId ?? ''}',
        'X-Contrasenia': contrasenia ?? '',
      };

  Future<void> _listarContactos() async {
    if (corredorId == null || contrasenia == null) return;
    setState(() => _cargando = true);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/contactos'),
        headers: _encabezadosAuth(),
      );
      if (response.statusCode == 200) {
        final data = (jsonDecode(response.body) as List)
            .map((e) => (e as Map<String, dynamic>))
            .toList();
        setState(() => _contactos = data);
      } else {
        _mostrarSnack('Error al obtener contactos (${response.statusCode})');
      }
    } catch (e) {
      _mostrarSnack('Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarContacto(int contactoId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/contactos/$contactoId'),
        headers: _encabezadosAuth(),
      );
      if (response.statusCode == 200) {
        _mostrarSnack('Contacto eliminado correctamente');
        _listarContactos();
      } else {
        _mostrarSnack('Error al eliminar (${response.statusCode})');
      }
    } catch (e) {
      _mostrarSnack('Error: $e');
    }
  }

  void _mostrarSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _mostrarModalAgregarEditar({Map<String, dynamic>? contacto}) {
    if (!_usuarioCargado || corredorId == null || contrasenia == null) {
      _mostrarSnack('Espera a que se cargue tu sesión antes de agregar contactos.');
      return;
    }

    // 🔒 Límite de 5 contactos (solo al crear)
    if (contacto == null && _contactos.length >= 5) {
      _mostrarSnack('Solo puedes registrar hasta 5 contactos de confianza.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: HojaAgregarEditarContacto(
            contacto: contacto,
            corredorId: corredorId!,
            contrasenia: contrasenia!,
            onSave: _listarContactos,
            totalContactos: _contactos.length,
          ),
        );
      },
    );
  }

  void _confirmarEliminar(int contactoId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Eliminar contacto"),
        content: const Text("¿Seguro que deseas eliminar este contacto de confianza?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _eliminarContacto(contactoId);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_usuarioCargado) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    return Scaffold(
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _contactos.isEmpty
              ? _construirEstadoVacio()
              : RefreshIndicator(
                  onRefresh: _listarContactos,
                  color: primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _contactos.length,
                    itemBuilder: (context, index) {
                      final c = _contactos[index];
                      final id = (c['contacto_id'] as num).toInt();
                      final nombre = (c['nombre'] ?? '') as String;
                      final tel = (c['telefono'] ?? '') as String;
                      final rel = (c['relacion'] ?? 'N/A') as String;

                      return Card(
                        color: cardColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: primaryColor,
                            child: Icon(Icons.person, color: Colors.black),
                          ),
                          title: Text(nombre),
                          subtitle: Text("$rel • $tel"),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _mostrarModalAgregarEditar(contacto: c);
                              } else if (value == 'delete') {
                                _confirmarEliminar(id);
                              }
                            },
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(value: 'edit', child: Text('Editar')),
                              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
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
            _mostrarSnack('Solo puedes registrar hasta 5 contactos de confianza.');
          } else {
            _mostrarModalAgregarEditar();
          }
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _construirEstadoVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_in_talk, color: Colors.grey[600], size: 60),
            const SizedBox(height: 20),
            const Text('No hay contactos agregados',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              'Agrega contactos de confianza para recibir alertas\ncuando necesites ayuda',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// FORMULARIO DE AGREGAR / EDITAR CONTACTO
// -------------------------------------------------------------
class HojaAgregarEditarContacto extends StatefulWidget {
  final Map<String, dynamic>? contacto;
  final int corredorId;
  final String contrasenia;
  final VoidCallback onSave;
  final int totalContactos;

  const HojaAgregarEditarContacto({
    this.contacto,
    required this.corredorId,
    required this.contrasenia,
    required this.onSave,
    required this.totalContactos,
  });

  @override
  State<HojaAgregarEditarContacto> createState() => EstadoHojaAgregarEditarContacto();
}

class EstadoHojaAgregarEditarContacto extends State<HojaAgregarEditarContacto> {
  final nombreController = TextEditingController();
  final telefonoController = TextEditingController();
  final relacionController = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    if (widget.contacto != null) {
      nombreController.text = widget.contacto!['nombre'] ?? '';
      telefonoController.text = widget.contacto!['telefono'] ?? '';
      relacionController.text = widget.contacto!['relacion'] ?? '';
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    telefonoController.dispose();
    relacionController.dispose();
    super.dispose();
  }

  Future<void> _guardarContacto() async {
    // Revalida límite por si se quedó abierto el modal y el usuario añadió uno
    if (widget.contacto == null && widget.totalContactos >= 5) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Solo puedes tener hasta 5 contactos.')));
      Navigator.of(context).pop();
      return;
    }

    final nombre = nombreController.text.trim();
    final telefonoRaw = telefonoController.text.trim();
    final relacion = relacionController.text.trim();

    if (nombre.isEmpty || telefonoRaw.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Por favor llena los campos obligatorios')));
      return;
    }

    // --- Normaliza el teléfono a solo dígitos ---
    String telefonoDigits = telefonoRaw.replaceAll(RegExp(r'\D'), '');
    // Casos comunes MX: 521xxxxxxxxxx (WhatsApp), 52xxxxxxxxxx
    if (telefonoDigits.length == 13 && telefonoDigits.startsWith('521')) {
      telefonoDigits = telefonoDigits.substring(3);
    } else if (telefonoDigits.length == 12 && telefonoDigits.startsWith('52')) {
      telefonoDigits = telefonoDigits.substring(2);
    }

    // Validación estricta MX: exactamente 10 dígitos
    if (telefonoDigits.length != 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('El teléfono debe tener exactamente 10 dígitos.')));
      return;
    }

    setState(() => _guardando = true);

    final body = <String, dynamic>{
      'nombre': nombre,
      'telefono': telefonoDigits,
      'relacion': relacion.isEmpty ? 'N/A' : relacion,
    };

    final creando = widget.contacto == null;
    final url = creando
        ? Uri.parse('$_baseUrl/contactos')
        : Uri.parse('$_baseUrl/contactos/${(widget.contacto!['contacto_id'] as num).toInt()}');

    try {
      final resp = await (creando
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

      if (!mounted) return;

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        Navigator.of(context).pop();
        widget.onSave();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error (${resp.statusCode}): ${resp.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.contacto == null ? 'Agregar Contacto' : 'Editar Contacto',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 20),
          _construirCampoTexto('Nombre *', nombreController),
          const SizedBox(height: 16),
          _construirCampoTexto(
            'Teléfono *',
            telefonoController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          _construirCampoTexto('Relación (opcional)', relacionController),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardarContacto,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _guardando
                  ? const CircularProgressIndicator(color: Colors.black)
                  : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirCampoTexto(
    String etiqueta,
    TextEditingController controlador, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controlador,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: etiqueta,
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
