// lib/screens/vista_contactos.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../backend/core/session_repository.dart';
import '../backend/dominio/contactos.dart';
import '../backend/dominio/modelos/contacto.dart';

class VistaContactos extends StatefulWidget {
  const VistaContactos({super.key});

  @override
  State<VistaContactos> createState() => EstadoVistaContactos();
}

class EstadoVistaContactos extends State<VistaContactos> {
  List<Contacto> _contactos = [];
  bool _cargando = false;
  int? corredorId;
  String? contrasenia;
  bool _usuarioCargado = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Cargar credenciales desde backend/core/session_repository.dart
    corredorId = await RepositorioSesion.obtenerCorredorId();
    contrasenia = await RepositorioSesion.obtenerContrasenia();
    setState(() => _usuarioCargado = true);

    if (corredorId != null && contrasenia != null) {
      await _listarContactos();
    }
  }

  Future<void> _listarContactos() async {
    if (corredorId == null || contrasenia == null) return;
    setState(() => _cargando = true);
    try {
      final data = await ContactosUC.listar(
        corredorId: corredorId,
        contrasenia: contrasenia,
      );
      setState(() => _contactos = data);
    } catch (e) {
      _snack('Error al obtener contactos: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarContacto(int contactoId) async {
    try {
      await ContactosUC.eliminar(
        contactoId: contactoId,
        corredorId: corredorId,
        contrasenia: contrasenia,
      );
      _snack('Contacto eliminado correctamente');
      await _listarContactos();
    } catch (e) {
      _snack('Error al eliminar: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _mostrarModalAgregarEditar({Contacto? contacto}) {
    if (!_usuarioCargado || corredorId == null || contrasenia == null) {
      _snack('Espera a que se cargue tu sesión antes de agregar contactos.');
      return;
    }

    // 🔒 Límite de 5 contactos (solo al crear)
    if (contacto == null && _contactos.length >= 5) {
      _snack('Solo puedes registrar hasta 5 contactos de confianza.');
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
            onSaved: _listarContactos,
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
            onPressed: () async {
              Navigator.pop(ctx);
              await _eliminarContacto(contactoId);
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
              ? _estadoVacio()
              : RefreshIndicator(
                  onRefresh: _listarContactos,
                  color: primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _contactos.length,
                    itemBuilder: (context, index) {
                      final c = _contactos[index];
                      return Card(
                        color: cardColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: primaryColor,
                            child: Icon(Icons.person, color: Colors.black),
                          ),
                          title: Text(c.nombre),
                          subtitle: Text("${c.relacion} • ${c.telefono}"),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _mostrarModalAgregarEditar(contacto: c);
                              } else if (value == 'delete') {
                                _confirmarEliminar(c.id);
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
            _snack('Solo puedes registrar hasta 5 contactos de confianza.');
          } else {
            _mostrarModalAgregarEditar();
          }
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  Widget _estadoVacio() {
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
// FORMULARIO DE AGREGAR / EDITAR CONTACTO (UI)
// -------------------------------------------------------------
class HojaAgregarEditarContacto extends StatefulWidget {
  final Contacto? contacto;
  final int corredorId;
  final String contrasenia;
  final VoidCallback onSaved;
  final int totalContactos;

  const HojaAgregarEditarContacto({
    this.contacto,
    required this.corredorId,
    required this.contrasenia,
    required this.onSaved,
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
      nombreController.text = widget.contacto!.nombre;
      telefonoController.text = widget.contacto!.telefono;
      relacionController.text = widget.contacto!.relacion == 'N/A' ? '' : widget.contacto!.relacion;
    }
  }

  @override
  void dispose() {
    nombreController.dispose();
    telefonoController.dispose();
    relacionController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    // Revalida límite por si se quedó abierto el modal
    if (widget.contacto == null && widget.totalContactos >= 5) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Solo puedes tener hasta 5 contactos.')));
      Navigator.of(context).pop();
      return;
    }

    final nombre = nombreController.text.trim();
    final telefonoRaw = telefonoController.text.trim();
    final relacion = (relacionController.text.trim().isEmpty)
        ? 'N/A'
        : relacionController.text.trim();

    if (nombre.isEmpty || telefonoRaw.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Por favor llena los campos obligatorios')));
      return;
    }

    final telefono10 = ContactosUC.normalizarTelefonoMx10(telefonoRaw);
    if (telefono10.length != 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El teléfono debe tener exactamente 10 dígitos.')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      if (widget.contacto == null) {
        await ContactosUC.crear(
          nombre: nombre,
          telefono10: telefono10,
          relacion: relacion,
          corredorId: widget.corredorId,
          contrasenia: widget.contrasenia,
        );
      } else {
        await ContactosUC.actualizar(
          contactoId: widget.contacto!.id,
          nombre: nombre,
          telefono10: telefono10,
          relacion: relacion,
          corredorId: widget.corredorId,
          contrasenia: widget.contrasenia,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
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
          _campoTexto('Nombre *', nombreController),
          const SizedBox(height: 16),
          _campoTexto(
            'Teléfono *',
            telefonoController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 16),
          _campoTexto('Relación (opcional)', relacionController),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
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

  Widget _campoTexto(
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
