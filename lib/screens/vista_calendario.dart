// lib/screens/vista_calendario.dart
import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'vista_estadistica.dart';

import '../main.dart'; // colores

// =============================
// Config API
// =============================
const String _baseUrl = 'http://157.137.187.110:8000';

// =============================
// Modelo / utilidades de estado
// =============================
enum RaceStatus { pendiente, hecha, noRealizada }

String _statusToApi(RaceStatus s) {
  switch (s) {
    case RaceStatus.hecha:
      return 'hecha';
    case RaceStatus.noRealizada:
      return 'no_realizada';
    case RaceStatus.pendiente:
    default:
      return 'pendiente';
  }
}

RaceStatus _statusFromApi(String s) {
  switch (s) {
    case 'hecha':
      return RaceStatus.hecha;
    case 'no_realizada':
      return RaceStatus.noRealizada;
    case 'pendiente':
    default:
      return RaceStatus.pendiente;
  }
}

class Race {
  /// id > 0 => viene del servidor
  /// id < 0 => creada local/offline (temporal, pendiente de subir)
  int id;
  String title;
  DateTime dateTime; // en local (UI)
  RaceStatus status;
  int tzOffsetMin;

  Race({
    required this.id,
    required this.title,
    required this.dateTime,
    this.status = RaceStatus.pendiente,
    this.tzOffsetMin = 0,
  });

  // ===== Caché local =====
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dateTime': dateTime.toIso8601String(),
        'status': status.index,
        'tzOffsetMin': tzOffsetMin,
      };

  static Race fromJson(Map<String, dynamic> m) => Race(
        id: m['id'] as int,
        title: m['title'] as String,
        dateTime: DateTime.parse(m['dateTime'] as String),
        status: RaceStatus.values[(m['status'] as int?) ?? 0],
        tzOffsetMin: (m['tzOffsetMin'] as int?) ?? 0,
      );

  // ===== Mapear API =====
  static Race fromApi(Map<String, dynamic> m) {
    final utc = DateTime.parse(m['fecha_hora_utc'] as String).toUtc();
    return Race(
      id: m['carrera_id'] as int,
      title: m['titulo'] as String,
      dateTime: utc.toLocal(),
      status: _statusFromApi(m['estado'] as String),
      tzOffsetMin: (m['tz_offset_min'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toApiCreateOrUpdate() => {
        'titulo': title,
        'fecha_hora_utc': dateTime.toUtc().toIso8601String(),
        'tz_offset_min': DateTime.now().timeZoneOffset.inMinutes,
        'estado': _statusToApi(status),
      };

  Race clone() => Race(
        id: id,
        title: title,
        dateTime: dateTime,
        status: status,
        tzOffsetMin: tzOffsetMin,
      );
}

// =============================
// Vista principal
// =============================
class VistaCalendario extends StatefulWidget {
  const VistaCalendario({super.key});

  @override
  State<VistaCalendario> createState() => _VistaCalendarioState();
}

class _VistaCalendarioState extends State<VistaCalendario> {
  final List<Race> _races = [];
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  late CalendarFormat _calendarFormat;
  Map<DateTime, List<Race>> _events = {};

  static const _storageKey = 'races_storage_v1';

  // Estilo contactos:
  bool _isLoading = false;
  int? corredorId;
  String? contrasenia;
  bool _isUserLoaded = false;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _calendarFormat = CalendarFormat.month;
    _loadRacesFromDisk();     // pinta caché primero
    _cargarDatosUsuario();    // luego servidor + sync
  }

  // =============================
  // User / Auth helpers
  // =============================
  Future<void> _cargarDatosUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    corredorId = prefs.getInt('corredor_id');
    contrasenia = prefs.getString('contrasenia');

    setState(() => _isUserLoaded = true);

    if (corredorId != null && contrasenia != null) {
      await _fetchCarreras();     // carga del servidor
      await _syncLocalDrafts();   // intenta subir locales (id<0)
    }
  }

  Map<String, String> _authHeaders() => {
        'X-Corredor-Id': '${corredorId ?? ''}',
        'X-Contrasenia': contrasenia ?? '',
      };

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // =============================
  // Persistencia local
  // =============================
  Future<void> _loadRacesFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    _races.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final List list = jsonDecode(raw) as List;
        _races.addAll(list.map((e) => Race.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        // datos corruptos => ignora
      }
    }
    _races.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    _groupEvents();
    if (mounted) setState(() {});
  }

  Future<void> _saveRacesToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_races.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  void _groupEvents() {
    _events = {};
    for (var race in _races) {
      final date = DateTime(race.dateTime.year, race.dateTime.month, race.dateTime.day);
      _events.putIfAbsent(date, () => []).add(race);
    }
  }

  List<Race> _getEventsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _events[date] ?? [];
  }

  // =============================
  // API: listar / crear / actualizar / eliminar
  // =============================
  Future<void> _fetchCarreras() async {
    if (corredorId == null || contrasenia == null) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/carreras'),
        headers: _authHeaders(),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body) as List;
        final server = data.map((e) => Race.fromApi(e as Map<String, dynamic>)).toList();

        // Conserva locales no subidas (id<0)
        final localOnly = _races.where((r) => r.id < 0).toList();

        _races
          ..clear()
          ..addAll(server)
          ..addAll(localOnly);

        _races.sort((a, b) => a.dateTime.compareTo(b.dateTime));
        _groupEvents();
        await _saveRacesToDisk();
        setState(() {});
      } else {
        _showSnack('Error al obtener carreras (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      // sin internet: mantén caché
      // _showSnack('Sin conexión. Mostrando datos locales.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncLocalDrafts() async {
    // intenta subir cada carrera con id<0
    final drafts = _races.where((r) => r.id < 0).toList();
    for (final local in drafts) {
      try {
        final resp = await http.post(
          Uri.parse('$_baseUrl/carreras'),
          headers: {
            ..._authHeaders(),
            'Content-Type': 'application/json',
          },
          body: jsonEncode(local.toApiCreateOrUpdate()),
        );
        if (resp.statusCode == 201) {
          final created = Race.fromApi(jsonDecode(resp.body) as Map<String, dynamic>);
          // reemplaza en la misma posición
          final idx = _races.indexWhere((r) => r.id == local.id);
          if (idx != -1) {
            _races[idx] = created;
          }
        } else {
          // servidor rechazó, lo dejamos local pero NO decimos "sin conexión"
          // (evitamos ruido)
        }
      } catch (_) {
        // sin conexión: salimos silenciosamente
        break;
      }
    }
    _races.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    _groupEvents();
    await _saveRacesToDisk();
    if (mounted) setState(() {});
  }

  // =============================
  // Acciones UI
  // =============================
  Future<void> _saveRace(String title, DateTime dateTime, RaceStatus status,
      {Race? existingRace}) async {
    // ✅ Validar "futura" SOLO si es creación (sin existingRace) o si es borrador local (id < 0)
    final mustBeFuture = (existingRace == null) || (existingRace.id < 0);
    if (mustBeFuture && !dateTime.isAfter(DateTime.now())) {
      _showSnack('La carrera debe programarse en una fecha y hora futura.');
      return;
    }

    // ===== EDITAR =====
    if (existingRace != null) {
      final backup = existingRace.clone();
      existingRace.title = title;
      existingRace.dateTime = dateTime;
      existingRace.status = status;
      existingRace.tzOffsetMin = DateTime.now().timeZoneOffset.inMinutes;

      // (1) Si es local (id<0): realmente es "creación" (POST)
      if (existingRace.id < 0) {
        try {
          final resp = await http.post(
            Uri.parse('$_baseUrl/carreras'),
            headers: {
              ..._authHeaders(),
              'Content-Type': 'application/json',
            },
            body: jsonEncode(existingRace.toApiCreateOrUpdate()),
          );
          if (resp.statusCode == 201) {
            final created = Race.fromApi(jsonDecode(resp.body) as Map<String, dynamic>);
            final idx = _races.indexWhere((r) => r.id == existingRace.id);
            if (idx != -1) _races[idx] = created;
            _showSnack('Carrera registrada.');
          } else {
            final idx = _races.indexWhere((r) => r.id == existingRace.id);
            if (idx != -1) _races[idx] = backup;
            _showSnack('Error (${resp.statusCode}): ${resp.body}');
          }
        } on SocketException catch (_) {
          _showSnack('Sin conexión. Cambios guardados sólo localmente.');
        } on TimeoutException catch (_) {
          _showSnack('Sin conexión (timeout). Cambios locales.');
        } on http.ClientException catch (_) {
          _showSnack('Sin conexión. Cambios locales.');
        }
      } else {
        // (2) Remota (id>0): PUT (sin validar "futura")
        try {
          final resp = await http.put(
            Uri.parse('$_baseUrl/carreras/${existingRace.id}'),
            headers: {
              ..._authHeaders(),
              'Content-Type': 'application/json',
            },
            body: jsonEncode(existingRace.toApiCreateOrUpdate()),
          );
          if (resp.statusCode == 200) {
            _showSnack('Carrera actualizada correctamente');
          } else {
            // revertimos en error de servidor
            existingRace.title = backup.title;
            existingRace.dateTime = backup.dateTime;
            existingRace.status = backup.status;
            existingRace.tzOffsetMin = backup.tzOffsetMin;
            _showSnack('Error (${resp.statusCode}): ${resp.body}');
          }
        } on SocketException catch (_) {
          _showSnack('Sin conexión. Cambios guardados sólo localmente.');
        } on TimeoutException catch (_) {
          _showSnack('Sin conexión (timeout). Cambios locales.');
        } on http.ClientException catch (_) {
          _showSnack('Sin conexión. Cambios locales.');
        }
      }
    }

    // ===== NUEVA =====
    else {
      try {
        final draft = Race(
          id: 0, // temporal; si sale bien el POST no se usa
          title: title,
          dateTime: dateTime,
          status: status,
          tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
        );

        final resp = await http.post(
          Uri.parse('$_baseUrl/carreras'),
          headers: {
            ..._authHeaders(),
            'Content-Type': 'application/json',
          },
          body: jsonEncode(draft.toApiCreateOrUpdate()),
        );
        if (resp.statusCode == 201) {
          final created = Race.fromApi(jsonDecode(resp.body) as Map<String, dynamic>);
          _races.add(created);
          _showSnack('Carrera registrada.');
        } else {
          _showSnack('Error (${resp.statusCode}): ${resp.body}');
        }
      } on SocketException catch (_) {
        // sin conexión => guardamos local
        final local = Race(
          id: -DateTime.now().millisecondsSinceEpoch,
          title: title,
          dateTime: dateTime,
          status: status,
          tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
        );
        _races.add(local);
        _showSnack('Sin conexión. Carrera guardada localmente.');
      } on TimeoutException catch (_) {
        final local = Race(
          id: -DateTime.now().millisecondsSinceEpoch,
          title: title,
          dateTime: dateTime,
          status: status,
          tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
        );
        _races.add(local);
        _showSnack('Sin conexión (timeout). Guardada localmente.');
      } on http.ClientException catch (_) {
        final local = Race(
          id: -DateTime.now().millisecondsSinceEpoch,
          title: title,
          dateTime: dateTime,
          status: status,
          tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
        );
        _races.add(local);
        _showSnack('Sin conexión. Guardada localmente.');
      }
    }

    _races.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    _groupEvents();
    await _saveRacesToDisk();
    if (mounted) setState(() {});
  }

  Future<void> _updateRaceStatus(Race race, RaceStatus newStatus) async {
    final prev = race.status;
    race.status = newStatus;

    if (race.id <= 0) {
      // local: mantenemos cambio y se sincroniza luego
      _showSnack('Estado guardado localmente.');
      await _saveRacesToDisk();
      if (mounted) setState(() {});
      return;
    }

    try {
      final resp = await http.patch(
        Uri.parse('$_baseUrl/carreras/${race.id}/estado?estado=${_statusToApi(newStatus)}'),
        headers: _authHeaders(),
      );
      if (resp.statusCode == 200) {
        _showSnack('Estado de la carrera actualizado.');
      } else {
        race.status = prev; // revertimos en error de servidor
        _showSnack('Error (${resp.statusCode}): ${resp.body}');
      }
    } on SocketException catch (_) {
      _showSnack('Sin conexión. Estado guardado sólo localmente.');
    } on TimeoutException catch (_) {
      _showSnack('Sin conexión (timeout). Estado local.');
    } on http.ClientException catch (_) {
      _showSnack('Sin conexión. Estado local.');
    }

    await _saveRacesToDisk();
    if (mounted) setState(() {});
  }

  Future<void> _deleteRace(Race race) async {
    if (race.id > 0) {
      try {
        final resp = await http.delete(
          Uri.parse('$_baseUrl/carreras/${race.id}'),
          headers: _authHeaders(),
        );
        if (resp.statusCode != 200) {
          _showSnack('Error al eliminar (${resp.statusCode}): ${resp.body}');
          return;
        }
      } on SocketException catch (_) {
        _showSnack('Sin conexión. No se pudo eliminar en servidor.');
        return;
      } on TimeoutException catch (_) {
        _showSnack('Sin conexión (timeout). No se pudo eliminar en servidor.');
        return;
      } on http.ClientException catch (_) {
        _showSnack('Sin conexión. No se pudo eliminar en servidor.');
        return;
      }
    }
    // elimina local (también si era id<0)
    _races.removeWhere((r) => r.id == race.id);
    _groupEvents();
    await _saveRacesToDisk();
    if (mounted) setState(() {});
    _showSnack('Carrera eliminada.');
  }

  void _confirmDelete(Race race) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar carrera"),
        content: const Text("¿Seguro que deseas eliminar esta carrera?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteRace(race);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // =============================
  // Build
  // =============================
  @override
  Widget build(BuildContext context) {
    if (!_isUserLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    final selectedDayEvents = _getEventsForDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario de Carreras'),
        backgroundColor: backgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Ver estadísticas del mes',
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              final y = _focusedDay.year;
              final m = _focusedDay.month;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VistaEstadistica(year: y, month: m),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                _buildTableCalendar(),
                const Divider(height: 1),

                // ---------- Encabezado: "Carreras del día" + botón "+" ----------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Text(
                        "Carreras del día",
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Nueva carrera',
                        onPressed: () => _showRaceForm(selectedDay: _selectedDay),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),

                // ---------- Lista de eventos del día ----------
                Expanded(
                  child: selectedDayEvents.isEmpty
                      ? _buildEmptyDay()
                      : _buildEventList(selectedDayEvents),
                ),
              ],
            ),

      // ---------- FAB pequeño y discreto ----------
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
          child: FloatingActionButton.small(
            onPressed: () => _showRaceForm(selectedDay: _selectedDay),
            backgroundColor: primaryColor,
            foregroundColor: Colors.black,
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }


  Widget _buildTableCalendar() {
    return TableCalendar<Race>(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: _getEventsForDay,
      startingDayOfWeek: StartingDayOfWeek.monday,
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        todayDecoration: BoxDecoration(
          color: primaryColor.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        selectedDecoration: const BoxDecoration(
          color: primaryColor,
          shape: BoxShape.circle,
        ),
        markerDecoration: const BoxDecoration(
          color: accentColor,
          shape: BoxShape.circle,
        ),
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      onDaySelected: (selectedDay, focusedDay) {
        if (!isSameDay(_selectedDay, selectedDay)) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        }
        _showRaceForm(selectedDay: selectedDay);
      },
      onFormatChanged: (format) {
        if (_calendarFormat != format) {
          setState(() => _calendarFormat = format);
        }
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
      },
    );
  }

  Widget _buildEventList(List<Race> events) {
    // Deja espacio suficiente abajo para que el FAB nunca tape la última tarjeta
    final extraBottom = MediaQuery.of(context).padding.bottom + 80;

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, extraBottom),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final race = events[index];
        return _RaceCard(
          race: race,
          onStatusChanged: (newStatus) => _updateRaceStatus(race, newStatus),
          onEdit: () => _showRaceForm(race: race),
          onDelete: () => _confirmDelete(race),
        );
      },
    );
  }


  Widget _buildEmptyDay() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Text(
          "No hay carreras programadas.\nToca un día o el botón + para agregar una.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[400]),
        ),
      ),
    );
  }

  void _showRaceForm({Race? race, DateTime? selectedDay}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: _AddEditRaceSheet(
              onSave: (title, dateTime, status) =>
                  _saveRace(title, dateTime, status, existingRace: race),
              race: race,
              selectedDay: selectedDay,
            ),
          ),
        );
      },
    );
  }
}

class _RaceCard extends StatelessWidget {
  final Race race;
  final Function(RaceStatus) onStatusChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RaceCard({
    required this.race,
    required this.onStatusChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPast = race.dateTime.isBefore(DateTime.now());
    final statusData = _getStatusData(race.status);

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusData['icon'], color: statusData['color'], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        race.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _formatTime(TimeOfDay.fromDateTime(race.dateTime)),
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
            if (isPast && race.status == RaceStatus.pendiente) ...[
              const Divider(height: 20),
              _buildStatusSelector(),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _statusChip(RaceStatus.hecha, 'Hecha'),
        const SizedBox(width: 10),
        _statusChip(RaceStatus.noRealizada, 'No Realizada'),
      ],
    );
  }

  Widget _statusChip(RaceStatus status, String label) {
    final isSelected = race.status == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) onStatusChanged(status);
      },
      backgroundColor: Colors.grey.withOpacity(0.2),
      selectedColor: _getStatusData(status)['color'],
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Map<String, dynamic> _getStatusData(RaceStatus status) {
    switch (status) {
      case RaceStatus.hecha:
        return {'icon': Icons.check_circle, 'color': Colors.greenAccent};
      case RaceStatus.noRealizada:
        return {'icon': Icons.cancel, 'color': Colors.redAccent};
      case RaceStatus.pendiente:
      default:
        return {'icon': Icons.hourglass_top, 'color': primaryColor};
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

// --- FORMULARIO PARA AGREGAR/EDITAR ---
class _AddEditRaceSheet extends StatefulWidget {
  final Function(String title, DateTime dateTime, RaceStatus status) onSave;
  final Race? race;
  final DateTime? selectedDay;

  const _AddEditRaceSheet({required this.onSave, this.race, this.selectedDay});

  @override
  State<_AddEditRaceSheet> createState() => _AddEditRaceSheetState();
}

class _AddEditRaceSheetState extends State<_AddEditRaceSheet> {
  final _titleController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  RaceStatus _selectedStatus = RaceStatus.pendiente;

  @override
  void initState() {
    super.initState();
    if (widget.race != null) {
      _titleController.text = widget.race!.title;
      _selectedDate = widget.race!.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.race!.dateTime);
      _selectedStatus = widget.race!.status;
    } else if (widget.selectedDay != null) {
      _selectedDate = widget.selectedDay;
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    TimeOfDay tempTime = _selectedTime ?? TimeOfDay.now();

    await showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      builder: (BuildContext builder) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedTime = tempTime;
                        });
                        Navigator.of(context).pop();
                      },
                      child: const Text('Guardar',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                    _selectedTime?.hour ?? TimeOfDay.now().hour,
                    _selectedTime?.minute ?? TimeOfDay.now().minute,
                  ),
                  onDateTimeChanged: (DateTime newDateTime) {
                    tempTime = TimeOfDay.fromDateTime(newDateTime);
                  },
                  use24hFormat: MediaQuery.of(context).alwaysUse24HourFormat,
                  minuteInterval: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty || _selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos.')),
      );
      return;
    }
    final fullDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    widget.onSave(title, fullDateTime, _selectedStatus);
    Navigator.of(context).pop();
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
          Text(
            widget.race == null ? 'Programar Carrera' : 'Editar Carrera',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Título de la carrera'),
            style: const TextStyle(color: Colors.white),
            cursorColor: primaryColor,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<RaceStatus>(
            value: _selectedStatus,
            onChanged: (RaceStatus? newValue) {
              if (newValue != null) {
                setState(() => _selectedStatus = newValue);
              }
            },
            items: RaceStatus.values.map((RaceStatus status) {
              return DropdownMenuItem<RaceStatus>(
                value: status,
                child: Text(_statusToString(status)),
              );
            }).toList(),
            decoration: const InputDecoration(labelText: 'Estado'),
            dropdownColor: cardColor,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Fecha'),
                    child: Text(
                      _selectedDate == null
                          ? 'Seleccionar'
                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: _pickTime,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Hora'),
                    child: Text(
                      _selectedTime == null
                          ? 'Seleccionar'
                          : _selectedTime!.format(context),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              child: const Text('Guardar Carrera'),
            ),
          ),
        ],
      ),
    );
  }

  String _statusToString(RaceStatus status) {
    switch (status) {
      case RaceStatus.pendiente:
        return 'Pendiente';
      case RaceStatus.hecha:
        return 'Hecha';
      case RaceStatus.noRealizada:
        return 'No Realizada';
    }
  }
}