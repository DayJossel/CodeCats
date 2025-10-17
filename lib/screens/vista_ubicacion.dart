import 'dart:async';
import 'package:flutter/material.dart';

import '../main.dart'; // Colores (backgroundColor, primaryColor, cardColor)
import '../data/api_service.dart';
import '../core/session_repository.dart';
import '../device/location_service.dart';
import '../device/sms_service.dart';

/// View-model para pintar contactos en esta vista (¡este es el ContactVm!)
class ContactVm {
  final int contactoId;
  final String nombre;
  final String telefono;
  final String initials;

  ContactVm({
    required this.contactoId,
    required this.nombre,
    required this.telefono,
    required this.initials,
  });

  factory ContactVm.fromApi(Map<String, dynamic> j) {
    final nombre = (j['nombre'] as String?)?.trim() ?? 'Contacto';
    final tel = (j['telefono'] as String?)?.trim() ?? '';
    final id = (j['contacto_id'] as num).toInt();
    return ContactVm(
      contactoId: id,
      nombre: nombre,
      telefono: tel,
      initials: _buildInitials(nombre),
    );
  }

  static String _buildInitials(String full) {
    // Sin package:characters, para evitar imports extra
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
  State<VistaUbicacion> createState() => _VistaUbicacionState();
}

class _VistaUbicacionState extends State<VistaUbicacion> {
  List<ContactVm> _contacts = [];
  final Set<int> _selectedIds = {};
  bool _loading = true;
  String? _error;

  Timer? _sessionTimer;
  DateTime? _sessionEndAt;
  Duration _sessionFrequency = const Duration(minutes: 10);
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _cancelSession();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getContactos(); // [{contacto_id, nombre, telefono, ...}]
      final mapped = list
          .map(ContactVm.fromApi)
          .where((c) => c.telefono.isNotEmpty)
          .toList();
      setState(() {
        _contacts = mapped;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'No se pudieron cargar tus contactos. $e';
        _loading = false;
      });
    }
  }

  void _onContactTap(ContactVm contact) {
    setState(() {
      if (_selectedIds.contains(contact.contactoId)) {
        _selectedIds.remove(contact.contactoId);
      } else {
        _selectedIds.add(contact.contactoId);
      }
    });
  }

  void _openConfirmationDialog() {
    final seleccion =
        _contacts.where((c) => _selectedIds.contains(c.contactoId)).toList();
    showDialog(
      context: context,
      builder: (context) => _ConfirmationDialog(
        selectedContacts: seleccion,
        onConfirm: (frequency, totalDuration) async {
          Navigator.of(context).pop(); // cierra diálogo de confirmación
          await _startShareSession(
            frequency: frequency,
            total: totalDuration,
            selected: seleccion,
          );
        },
      ),
    );
  }

  Future<void> _startShareSession({
    required Duration frequency,
    required Duration total,
    required List<ContactVm> selected,
  }) async {
    // 1) Permisos SMS/Teléfono
    try {
      await SmsService.ensureSmsAndPhonePermissions();
    } catch (e) {
      _snack('No se obtuvieron permisos para SMS/Teléfono.');
      return;
    }

    // 2) Preparar sesión (envío inmediato + periódicos)
    _cancelSession();
    final endAt = DateTime.now().add(total);
    setState(() {
      _sessionEndAt = endAt;
      _sessionFrequency = frequency;
    });

    // Envío inmediato (tick 0)
    await _sendLocationTo(selected);

    // Envío periódico
    _sessionTimer = Timer.periodic(frequency, (t) async {
      if (DateTime.now().isAfter(endAt)) {
        _cancelSession();
        _showSuccessDialog(selected);
        return;
      }
      await _sendLocationTo(selected);
    });

    _snack(
        'Sesión iniciada: cada ${_fmtDuration(frequency)} durante ${_fmtDuration(total)}.');
  }

  void _cancelSession() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _sessionEndAt = null;
  }

  Future<void> _sendLocationTo(List<ContactVm> selected) async {
    if (_sending) return;
    _sending = true;
    try {
      // 3) Ubicación (best-effort)
      double? lat, lng;
      try {
        final pos = await LocationService.getCurrentPosition();
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {
        lat = null;
        lng = null;
      }

      final corredor = await SessionRepository.nombre() ?? 'Corredor';
      final urlMapa = (lat != null && lng != null)
          ? LocationService.mapsUrlFrom(lat, lng)
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
          await SmsService.sendFlexibleMx(rawPhone: tel, message: mensaje);
          ok++;
        } catch (_) {
          fail++;
        }
      }

      if (mounted) {
        _snack('Ubicación enviada: $ok OK, $fail fallidos.');
      }
    } finally {
      _sending = false;
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSuccessDialog(List<ContactVm> selected) {
    showDialog(
      context: context,
      builder: (context) => _SuccessDialog(
        selectedContacts: selected,
        onDone: () {
          Navigator.of(context).pop(); // cierra diálogo
          if (mounted) Navigator.of(context).pop(); // cierra pantalla
        },
      ),
    );
  }

  String _fmtDuration(Duration d) {
    if (d.inMinutes % 60 == 0) return '${d.inHours} h';
    return '${d.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _selectedIds.isNotEmpty && !_loading && _error == null;

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
                if (_sessionEndAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Sesión activa: cada ${_fmtDuration(_sessionFrequency)} hasta '
                    '${_sessionEndAt!.toLocal()}',
                    style: const TextStyle(color: Colors.greenAccent),
                  ),
                ],
              ],
            ),
          ),

          // Lista / estados
          Expanded(
            child: _loading
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
                        itemCount: _contacts.length,
                        itemBuilder: (context, index) {
                          final c = _contacts[index];
                          final isSelected =
                              _selectedIds.contains(c.contactoId);
                          return _ContactTile(
                            contact: c,
                            isSelected: isSelected,
                            onTap: () => _onContactTap(c),
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
                onPressed: canContinue ? _openConfirmationDialog : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  disabledBackgroundColor: Colors.grey[800],
                ),
                child: Text(
                  canContinue
                      ? 'Continuar (${_selectedIds.length})'
                      : 'Continuar',
                  style: TextStyle(
                    color: canContinue ? Colors.black : Colors.grey[600],
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

class _ContactTile extends StatelessWidget {
  final ContactVm contact;
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

class _ConfirmationDialog extends StatefulWidget {
  final List<ContactVm> selectedContacts;
  final void Function(Duration frequency, Duration totalDuration) onConfirm;

  const _ConfirmationDialog({
    required this.selectedContacts,
    required this.onConfirm,
  });

  @override
  State<_ConfirmationDialog> createState() => _ConfirmationDialogState();
}

class _ConfirmationDialogState extends State<_ConfirmationDialog> {
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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿Quieres compartir tu ubicación con los contactos seleccionados?'),
          const SizedBox(height: 20),
          const Text('Frecuencia de actualización',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
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
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Duración de la sesión',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                onPressed: () =>
                    widget.onConfirm(_freqDuration, _totalDuration),
                child: const Text('Compartir'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  final List<ContactVm> selectedContacts;
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