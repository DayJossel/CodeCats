// lib/screens/vista_calendario.dart
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../main.dart'; // colores
import '../core/notification_service.dart';

// --- MODELO DE DATOS ---
enum RaceStatus { pendiente, hecha, noRealizada }

class Race {
  int id;
  String title;
  DateTime dateTime;
  RaceStatus status;

  Race({
    required this.id,
    required this.title,
    required this.dateTime,
    this.status = RaceStatus.pendiente,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'dateTime': dateTime.toIso8601String(),
        'status': status.index,
      };

  static Race fromJson(Map<String, dynamic> m) => Race(
        id: m['id'] as int,
        title: m['title'] as String,
        dateTime: DateTime.parse(m['dateTime'] as String),
        status: RaceStatus.values[(m['status'] as int?) ?? 0],
      );
}

// --- WIDGET PRINCIPAL DEL CALENDARIO ---
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

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = _focusedDay;
    _calendarFormat = CalendarFormat.month;
    _loadRacesFromDisk();
  }

  Future<void> _loadRacesFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    _races.clear();
    if (raw != null && raw.isNotEmpty) {
      final List list = jsonDecode(raw) as List;
      _races.addAll(list.map((e) => Race.fromJson(e as Map<String, dynamic>)));
    }
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

  Future<void> _saveRace(String title, DateTime dateTime, RaceStatus status,
      {Race? existingRace}) async {
    if (dateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La carrera debe programarse en una fecha y hora futura.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (existingRace != null) {
      final changedDate = existingRace.dateTime != dateTime;
      final changedTitle = existingRace.title != title;

      existingRace.title = title;
      existingRace.dateTime = dateTime;
      existingRace.status = status;

      if (status != RaceStatus.pendiente) {
        await NotificationService.instance.cancelRaceReminder(existingRace.id);
      } else if (changedDate || changedTitle) {
        await NotificationService.instance.cancelRaceReminder(existingRace.id);
        final ok = await NotificationService.instance.scheduleRaceReminder(
          raceId: existingRace.id,
          title: existingRace.title,
          raceDateTimeLocal: existingRace.dateTime,
        );
        if (!ok) _showCouldNotScheduleSnack();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carrera actualizada con éxito.')),
      );
    } else {
      final newRace = Race(
        id: DateTime.now().millisecondsSinceEpoch,
        title: title,
        dateTime: dateTime,
        status: status,
      );
      _races.add(newRace);

      if (status == RaceStatus.pendiente) {
        final ok = await NotificationService.instance.scheduleRaceReminder(
          raceId: newRace.id,
          title: newRace.title,
          raceDateTimeLocal: newRace.dateTime,
        );
        if (!ok) {
          _showCouldNotScheduleSnack();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Carrera registrada y recordatorio programado.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Carrera registrada.')),
        );
      }
    }

    _races.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    _groupEvents();
    await _saveRacesToDisk(); // ⬅️ persistimos cambios
    if (mounted) setState(() {});
  }

  void _showCouldNotScheduleSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Carrera registrada, pero no se pudo crear el recordatorio.\n'
          'Revisa permisos de notificaciones y de alarmas exactas.',
        ),
        action: SnackBarAction(
          label: 'Ajustes',
          onPressed: () {
            NotificationService.instance.openExactAlarmSettings();
          },
        ),
      ),
    );
  }

  Future<void> _updateRaceStatus(Race race, RaceStatus newStatus) async {
    race.status = newStatus;
    if (newStatus != RaceStatus.pendiente) {
      await NotificationService.instance.cancelRaceReminder(race.id);
    }
    await _saveRacesToDisk();
    if (mounted) setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Estado de la carrera actualizado.')),
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

  @override
  Widget build(BuildContext context) {
    final selectedDayEvents = _getEventsForDay(_selectedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario de Carreras'),
        backgroundColor: backgroundColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildTableCalendar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('Consultar Estadísticas'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Demo: estadísticas próximas.')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Botones de prueba de notificaciones visibles
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('Probar en 5s'),
                        onPressed: () async {
                          final ok = await NotificationService.instance.scheduleTestInSeconds(5);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Notificación de prueba programada en 5s'
                                  : 'No se pudo programar la prueba'),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.notifications),
                        label: const Text('Probar ahora'),
                        onPressed: () async {
                          await NotificationService.instance.showImmediateTest();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
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
              ],
            ),
          ),
          Expanded(
            child: selectedDayEvents.isEmpty
                ? _buildEmptyDay()
                : _buildEventList(selectedDayEvents),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_add_race',
        onPressed: () => _showRaceForm(selectedDay: _selectedDay),
        icon: const Icon(Icons.add),
        label: const Text('Nueva carrera'),
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final race = events[index];
        return _RaceCard(
          race: race,
          onStatusChanged: (newStatus) => _updateRaceStatus(race, newStatus),
          onEdit: () => _showRaceForm(race: race),
          onDelete: () async {
            await NotificationService.instance.cancelRaceReminder(race.id);
            _races.removeWhere((r) => r.id == race.id);
            _groupEvents();
            await _saveRacesToDisk();
            if (mounted) setState(() {});
          },
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
