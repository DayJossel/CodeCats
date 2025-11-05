import 'dart:async';
import 'package:flutter/material.dart';

import '../main.dart'; // Colores (backgroundColor, primaryColor, cardColor)
import '../data/api_service.dart';
import '../core/session_repository.dart';
import '../device/location_service.dart';
import '../device/sms_service.dart';

/// View-model para pintar contactos en esta vista
class ContactoVm {
  final int contactoId;
  final String nombre;
  final String telefono;
  final String initials;

  ContactoVm({
    required this.contactoId,
    required this.nombre,
    required this.telefono,
    required this.initials,
  });

  factory ContactoVm.desdeApi(Map<String, dynamic> j) {
    final nombre = (j['nombre'] as String?)?.trim() ?? 'Contacto';
    final tel = (j['telefono'] as String?)?.trim() ?? '';
    final id = (j['contacto_id'] as num).toInt();
    return ContactoVm(
      contactoId: id,
      nombre: nombre,
      telefono: tel,
      initials: _construirIniciales(nombre),
    );
  }

  static String _construirIniciales(String full) {
    final parts =
        full.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    String first(String s) => s.isEmpty ? '' : s[0].toUpperCase();
    if (parts.isEmpty) return 'C';
    if (parts.length == 1) return first(parts.first);
    return (first(parts.first) + first(parts.last));
  }
}

class VistaUbicacion extends StatefulWidget {
  const VistaUbicacion({super.key});

  @override
  State<VistaUbicacion> createState() => EstadoVistaUbicacion();
}

class EstadoVistaUbicacion extends State<VistaUbicacion> {
  List<ContactoVm> _contactos = [];
  final Set<int> _idsSeleccionados = {};
  bool _cargando = true;
  String? _error;

  Timer? _temporizadorSesion;
  DateTime? _finSesion;
  Duration _frecuenciaSesion = const Duration(minutes: 10);
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _cargarContactos();
  }

  @override
  void dispose() {
    _cancelarSesion();
    super.dispose();
  }

  Future<void> _cargarContactos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final list = await ServicioApi.obtenerContactos(); // [{contacto_id, nombre, telefono, ...}]
      final mapped = list
          .map(ContactoVm.desdeApi)
          .where((c) => c.telefono.isNotEmpty)
          .toList();
      setState(() {
        _contactos = mapped;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudieron cargar tus contactos. $e';
        _cargando = false;
      });
    }
  }

  void _alTocarContacto(ContactoVm contact) {
    setState(() {
      if (_idsSeleccionados.contains(contact.contactoId)) {
        _idsSeleccionados.remove(contact.contactoId);
      } else {
        _idsSeleccionados.add(contact.contactoId);
      }
    });
  }

  void _abrirDialogoConfirmacion() {
    final seleccion =
        _contactos.where((c) => _idsSeleccionados.contains(c.contactoId)).toList();
    showDialog(
      context: context,
      builder: (context) => DialogoConfirmacion(
        selectedContacts: seleccion,
        onConfirm: (frequency, totalDuration) async {
          Navigator.of(context).pop(); // cierra diálogo de confirmación
          await _iniciarSesionCompartir(
            frequency: frequency,
            total: totalDuration,
            selected: seleccion,
          );
        },
      ),
    );
  }

  Future<void> _iniciarSesionCompartir({
    required Duration frequency,
    required Duration total,
    required List<ContactoVm> selected,
  }) async {
    // 1) Permisos SMS/Teléfono
    try {
      await ServicioSMS.asegurarPermisosSmsYTelefono();
    } catch (e) {
      _mensaje('No se obtuvieron permisos para SMS/Teléfono.');
      return;
    }

    // 2) Preparar sesión (envío inmediato + periódicos)
    _cancelarSesion();
    final endAt = DateTime.now().add(total);
    setState(() {
      _finSesion = endAt;
      _frecuenciaSesion = frequency;
    });

    // Envío inmediato (tick 0)
    await _enviarUbicacionA(selected);

    // Envío periódico
    _temporizadorSesion = Timer.periodic(frequency, (t) async {
      if (DateTime.now().isAfter(endAt)) {
        _cancelarSesion();
        _mostrarDialogoExito(selected);
        return;
      }
      await _enviarUbicacionA(selected);
    });

    _mensaje('Sesión iniciada: cada ${_formatearDuracion(frequency)} durante ${_formatearDuracion(total)}.');
  }

  void _cancelarSesion() {
    _temporizadorSesion?.cancel();
    _temporizadorSesion = null;
    _finSesion = null;
  }

  Future<void> _enviarUbicacionA(List<ContactoVm> selected) async {
    if (_enviando) return;
    _enviando = true;
    try {
      // 3) Ubicación (best-effort)
      double? lat, lng;
      try {
        final pos = await ServicioUbicacion.obtenerPosicionActual();
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {
        lat = null;
        lng = null;
      }

      final corredor = await RepositorioSesion.nombre() ?? 'Corredor';
      final urlMapa = (lat != null && lng != null)
          ? ServicioUbicacion.urlMapsDesde(lat, lng)
          : 'no disponible';

      final mensaje = '''
📍 COMPARTIR UBICACIÓN – CHITA
Soy $corredor y estoy compartiendo mi ubicación.
Última ubicación:
$urlMapa
(Enviado automáticamente por CHITA)
'''.trim();

      // 4) Enviar SMS a cada contacto seleccionado
      int ok = 0, fail = 0;
      for (final c in selected) {
        final tel = c.telefono.trim();
        if (tel.isEmpty) {
          fail++;
          continue;
        }
        try {
          await ServicioSMS.enviarFlexibleMx(rawPhone: tel, message: mensaje);
          ok++;
        } catch (_) {
          fail++;
        }
      }

      if (mounted) {
        _mensaje('Ubicación enviada: $ok OK, $fail fallidos.');
      }
    } finally {
      _enviando = false;
    }
  }

  void _mensaje(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _mostrarDialogoExito(List<ContactoVm> selected) {
    showDialog(
      context: context,
      builder: (context) => DialogoExito(
        selectedContacts: selected,
        onDone: () {
          Navigator.of(context).pop(); // cierra diálogo
          if (mounted) Navigator.of(context).pop(); // cierra pantalla
        },
      ),
    );
  }

  String _formatearDuracion(Duration d) {
    if (d.inMinutes % 60 == 0) return '${d.inHours} h';
    return '${d.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    final puedeContinuar = _idsSeleccionados.isNotEmpty && !_cargando && _error == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compartir Ubicación'),
        backgroundColor: backgroundColor,
        elevation: 0,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Selecciona contactos',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                const Text('Elige con quién compartir tu ubicación',
                    style: TextStyle(color: Colors.grey)),
                if (_finSesion != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Sesión activa: cada ${_formatearDuracion(_frecuenciaSesion)} hasta '
                    '${_finSesion!.toLocal()}',
                    style: const TextStyle(color: Colors.greenAccent),
                  ),
                ],
              ],
            ),
          ),

          // Lista / estados
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : (_error != null)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(color: Colors.redAccent)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _contactos.length,
                        itemBuilder: (context, index) {
                          final c = _contactos[index];
                          final seleccionado =
                              _idsSeleccionados.contains(c.contactoId);
                          return ElementoContacto(
                            contact: c,
                            isSelected: seleccionado,
                            onTap: () => _alTocarContacto(c),
                          );
                        },
                      ),
          ),

          // Botón continuar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: puedeContinuar ? _abrirDialogoConfirmacion : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  disabledBackgroundColor: Colors.grey[800],
                ),
                child: Text(
                  puedeContinuar
                      ? 'Continuar (${_idsSeleccionados.length})'
                      : 'Continuar',
                  style: TextStyle(
                    color: puedeContinuar ? Colors.black : Colors.grey[600],
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

// ==========================
// Widgets auxiliares
// ==========================

class ElementoContacto extends StatelessWidget {
  final ContactoVm contact;
  final bool isSelected;
  final VoidCallback onTap;

  const ElementoContacto({
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
        child: Text(
          contact.initials,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title:
          Text(contact.nombre, style: const TextStyle(color: Colors.white)),
      subtitle:
          Text(contact.telefono, style: const TextStyle(color: Colors.grey)),
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

class DialogoConfirmacion extends StatefulWidget {
  final List<ContactoVm> selectedContacts;
  final void Function(Duration frequency, Duration totalDuration) onConfirm;

  const DialogoConfirmacion({
    required this.selectedContacts,
    required this.onConfirm,
  });

  @override
  State<DialogoConfirmacion> createState() => EstadoDialogoConfirmacion();
}

class EstadoDialogoConfirmacion extends State<DialogoConfirmacion> {
  String _selectedFrequency = '10 min';
  String _selectedDuration = '1h';

  Duration get _freqDuration {
    switch (_selectedFrequency) {
      case '30 min':
        return const Duration(minutes: 30);
      case '1 hora':
        return const Duration(hours: 1);
      default:
        return const Duration(minutes: 10);
    }
  }

  Duration get _totalDuration {
    switch (_selectedDuration) {
      case '2h':
        return const Duration(hours: 2);
      case '3h':
        return const Duration(hours: 3);
      case '4h':
        return const Duration(hours: 4);
      case '5h':
        return const Duration(hours: 5);
      default:
        return const Duration(hours: 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Confirmar compartir', textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Quieres compartir tu ubicación con los contactos seleccionados?',
            ),
            const SizedBox(height: 20),

            const Text('Frecuencia de actualización',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['10 min', '30 min', '1 hora'].map((freq) {
                final isSelected = _selectedFrequency == freq;
                return ChoiceChip(
                  label: Text(freq),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedFrequency = freq);
                  },
                  backgroundColor: Colors.grey[800],
                  selectedColor: primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            const Text('Duración de la sesión',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['1h', '2h', '3h', '4h', '5h'].map((duration) {
                final isSelected = _selectedDuration == duration;
                return ChoiceChip(
                  label: Text(duration),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedDuration = duration);
                  },
                  backgroundColor: Colors.grey[800],
                  selectedColor: primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ),
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
                onPressed: () => widget.onConfirm(_freqDuration, _totalDuration),
                child: const Text('Compartir'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DialogoExito extends StatelessWidget {
  final List<ContactoVm> selectedContacts;
  final VoidCallback onDone;

  const DialogoExito({required this.selectedContacts, required this.onDone});

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
          const Text('¡Ubicación compartida!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Se compartió tu ubicación con:'),
          const SizedBox(height: 16),
          ...selectedContacts.map((c) => Text('• ${c.nombre}')).toList(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDone,
              child: const Text('Entendido'),
            ),
          ),
        ],
      ),
    );
  }
}
