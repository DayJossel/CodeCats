// lib/screens/vista_calendario.dart
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../main.dart';
import 'vista_estadistica.dart';

import '../backend/dominio/modelos/carrera.dart';
import '../backend/dominio/calendario.dart';
import '../backend/core/session_repository.dart';

String _fmt(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
}

class VistaCalendario extends StatefulWidget {
  const VistaCalendario({super.key});

  @override
  State<VistaCalendario> createState() => EstadoVistaCalendario();
}

class EstadoVistaCalendario extends State<VistaCalendario> {
  final _uc = CalendarioUC();

  final List<Carrera> _carreras = [];
  late DateTime _diaEnfocado;
  late DateTime _diaSeleccionado;
  late CalendarFormat _formatoCalendario;
  Map<DateTime, List<Carrera>> _eventos = {};

  bool _cargando = false;
  int? corredorId;
  String? contrasenia;
  bool _usuarioCargado = false;

  @override
  void initState() {
    super.initState();
    _diaEnfocado = DateTime.now();
    _diaSeleccionado = _diaEnfocado;
    _formatoCalendario = CalendarFormat.month;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 1) Cargar caché local
    final local = await _uc.cargarDesdeDisco();
    _carreras
      ..clear()
      ..addAll(local);
    _eventos = _uc.agruparEventos(_carreras);
    if (mounted) setState(() {});

    // 2) Cargar credenciales (FIX de nombres)
    corredorId = await RepositorioSesion.obtenerCorredorId();
    contrasenia = await RepositorioSesion.obtenerContrasenia();
    _usuarioCargado = true;
    if (mounted) setState(() {});

    // 3) Si hay sesión, sincronizar servidor + borradores
    if (corredorId != null && contrasenia != null) {
      await _listarServidor();
      await _sincronizarBorradores();
    }
  }

  Future<void> _listarServidor() async {
    setState(() => _cargando = true);
    final merged = await _uc.listarCarrerasServidor(
      corredorId: corredorId,
      contrasenia: contrasenia,
      actuales: _carreras,
    );
    _carreras
      ..clear()
      ..addAll(merged);
    _eventos = _uc.agruparEventos(_carreras);
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _sincronizarBorradores() async {
    final upd = await _uc.sincronizarBorradores(
      corredorId: corredorId,
      contrasenia: contrasenia,
      carreras: _carreras,
    );
    _carreras
      ..clear()
      ..addAll(upd);
    _eventos = _uc.agruparEventos(_carreras);
    if (mounted) setState(() {});
  }

  void _mostrarSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _guardarCarrera(String titulo, DateTime fechaHora, EstadoCarrera estado,
      {Carrera? existente}) async {
    final upd = await _uc.guardarCarrera(
      corredorId: corredorId,
      contrasenia: contrasenia,
      titulo: titulo,
      fechaHora: fechaHora,
      estado: estado,
      existente: existente,
      onSnack: _mostrarSnack,
    );
    _carreras
      ..clear()
      ..addAll(upd);
    _carreras.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    _eventos = _uc.agruparEventos(_carreras);
    if (mounted) setState(() {});
  }

  Future<void> _actualizarEstado(Carrera c, EstadoCarrera nuevo) async {
    final upd = await _uc.actualizarEstado(
      corredorId: corredorId,
      contrasenia: contrasenia,
      carrera: c,
      nuevo: nuevo,
      onSnack: _mostrarSnack,
    );
    _carreras
      ..clear()
      ..addAll(upd);
    _eventos = _uc.agruparEventos(_carreras);
    if (mounted) setState(() {});
  }

  Future<void> _eliminarCarrera(Carrera c) async {
    final upd = await _uc.eliminarCarrera(
      corredorId: corredorId,
      contrasenia: contrasenia,
      carrera: c,
      onSnack: _mostrarSnack,
    );
    _carreras
      ..clear()
      ..addAll(upd);
    _eventos = _uc.agruparEventos(_carreras);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_usuarioCargado) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: primaryColor)));
    }

    final eventosDelSeleccionado = _eventos[_strip(_diaSeleccionado)] ?? [];

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
              final y = _diaEnfocado.year;
              final m = _diaEnfocado.month;
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => VistaEstadistica(year: y, month: m)));
            },
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                _construirCalendario(),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Text("Carreras del día",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Nueva carrera',
                        onPressed: () => _mostrarFormulario(diaSeleccionado: _diaSeleccionado),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: eventosDelSeleccionado.isEmpty
                      ? _buildEmptyDay()
                      : _construirListaEventos(eventosDelSeleccionado),
                ),
              ],
            ),
      // ⛔️ FAB eliminado (antes estaba aquí)
    );
  }

  DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);

  Widget _construirCalendario() {
    return TableCalendar<Carrera>(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _diaEnfocado,
      calendarFormat: _formatoCalendario,
      selectedDayPredicate: (day) => isSameDay(_diaSeleccionado, day),
      eventLoader: (day) => _eventos[_strip(day)] ?? [],
      startingDayOfWeek: StartingDayOfWeek.monday,
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        todayDecoration: BoxDecoration(color: primaryColor.withOpacity(0.5), shape: BoxShape.circle),
        selectedDecoration: const BoxDecoration(color: primaryColor, shape: BoxShape.circle),
        markerDecoration: const BoxDecoration(color: accentColor, shape: BoxShape.circle),
      ),
      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
      onDaySelected: (selectedDay, focusedDay) {
        if (!isSameDay(_diaSeleccionado, selectedDay)) {
          setState(() {
            _diaSeleccionado = selectedDay;
            _diaEnfocado = focusedDay;
          });
        }
        _mostrarFormulario(diaSeleccionado: selectedDay);
      },
      onFormatChanged: (format) {
        if (_formatoCalendario != format) {
          setState(() => _formatoCalendario = format);
        }
      },
      onPageChanged: (focusedDay) => _diaEnfocado = focusedDay,
    );
  }

  Widget _construirListaEventos(List<Carrera> eventos) {
    final extraBottom = MediaQuery.of(context).padding.bottom + 80;

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 0, 16, extraBottom),
      itemCount: eventos.length,
      itemBuilder: (context, index) {
        final c = eventos[index];
        return TarjetaCarrera(
          carrera: c,
          onEstadoCambiado: (nuevo) => _actualizarEstado(c, nuevo),
          onEditar: () => _mostrarFormulario(carrera: c),
          onEliminar: () => _confirmarEliminar(c),
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

  void _mostrarFormulario({Carrera? carrera, DateTime? diaSeleccionado}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
            child: HojaAgregarEditarCarrera(
              onSave: (titulo, fechaHora, estado) =>
                  _guardarCarrera(titulo, fechaHora, estado, existente: carrera),
              carrera: carrera,
              diaSeleccionado: diaSeleccionado,
            ),
          ),
        );
      },
    );
  }

  void _confirmarEliminar(Carrera c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar carrera"),
        content: const Text("¿Seguro que deseas eliminar esta carrera?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _eliminarCarrera(c);
              },
              child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

class TarjetaCarrera extends StatelessWidget {
  final Carrera carrera;
  final Function(EstadoCarrera) onEstadoCambiado;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const TarjetaCarrera({
    required this.carrera,
    required this.onEstadoCambiado,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final pasada = carrera.fechaHora.isBefore(DateTime.now());
    final data = _datosEstado(carrera.estado);

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
                Icon(data['icon'], color: data['color'], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(carrera.titulo,
                          style:
                              const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text(_formatearHora(TimeOfDay.fromDateTime(carrera.fechaHora)),
                          style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEditar();
                    if (value == 'delete') onEliminar();
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
            if (pasada && carrera.estado == EstadoCarrera.pendiente) ...[
              const Divider(height: 20),
              _selectorEstado(),
            ]
          ],
        ),
      ),
    );
  }

  Widget _selectorEstado() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _chipEstado(EstadoCarrera.hecha, 'Hecha'),
        const SizedBox(width: 10),
        _chipEstado(EstadoCarrera.noRealizada, 'No Realizada'),
      ],
    );
  }

  Widget _chipEstado(EstadoCarrera estado, String label) {
    final seleccionado = carrera.estado == estado;
    final data = _datosEstado(estado);
    return ChoiceChip(
      label: Text(label),
      selected: seleccionado,
      onSelected: (sel) {
        if (sel) onEstadoCambiado(estado);
      },
      backgroundColor: Colors.grey.withOpacity(0.2),
      selectedColor: data['color'],
      labelStyle: TextStyle(
        color: seleccionado ? Colors.black : Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Map<String, dynamic> _datosEstado(EstadoCarrera estado) {
    switch (estado) {
      case EstadoCarrera.hecha:
        return {'icon': Icons.check_circle, 'color': Colors.greenAccent};
      case EstadoCarrera.noRealizada:
        return {'icon': Icons.cancel, 'color': Colors.redAccent};
      case EstadoCarrera.pendiente:
      default:
        return {'icon': Icons.hourglass_top, 'color': primaryColor};
    }
  }

  String _formatearHora(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }
}

// --- Formulario agregar/editar ---
class HojaAgregarEditarCarrera extends StatefulWidget {
  final Function(String titulo, DateTime fechaHora, EstadoCarrera estado) onSave;
  final Carrera? carrera;
  final DateTime? diaSeleccionado;

  const HojaAgregarEditarCarrera({required this.onSave, this.carrera, this.diaSeleccionado});

  @override
  State<HojaAgregarEditarCarrera> createState() => EstadoHojaAgregarEditarCarrera();
}

class EstadoHojaAgregarEditarCarrera extends State<HojaAgregarEditarCarrera> {
  final _ctrlTitulo = TextEditingController();
  DateTime? _fecha;
  TimeOfDay? _hora;
  EstadoCarrera _estado = EstadoCarrera.pendiente;

  @override
  void initState() {
    super.initState();
    if (widget.carrera != null) {
      _ctrlTitulo.text = widget.carrera!.titulo;
      _fecha = widget.carrera!.fechaHora;
      _hora = TimeOfDay.fromDateTime(widget.carrera!.fechaHora);
      _estado = widget.carrera!.estado;
    } else if (widget.diaSeleccionado != null) {
      _fecha = widget.diaSeleccionado;
    }
  }

  Future<void> _seleccionarFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _fecha = d);
  }

  Future<void> _seleccionarHora() async {
    TimeOfDay tmp = _hora ?? TimeOfDay.now();
    await showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      builder: (ctx) => SizedBox(
        height: 300,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
                  TextButton(
                    onPressed: () {
                      setState(() => _hora = tmp);
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  _hora?.hour ?? TimeOfDay.now().hour,
                  _hora?.minute ?? TimeOfDay.now().minute,
                ),
                onDateTimeChanged: (dt) => tmp = TimeOfDay.fromDateTime(dt),
                use24hFormat: MediaQuery.of(context).alwaysUse24HourFormat,
                minuteInterval: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _guardar() {
    final titulo = _ctrlTitulo.text.trim();
    if (titulo.isEmpty || _fecha == null || _hora == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos.')),
      );
      return;
    }
    final full =
        DateTime(_fecha!.year, _fecha!.month, _fecha!.day, _hora!.hour, _hora!.minute);
    widget.onSave(titulo, full, _estado);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: cardColor,
        borderRadius:
            BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.carrera == null ? 'Programar Carrera' : 'Editar Carrera',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
            controller: _ctrlTitulo,
            decoration: const InputDecoration(labelText: 'Título de la carrera'),
            style: const TextStyle(color: Colors.white),
            cursorColor: primaryColor,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<EstadoCarrera>(
            value: _estado,
            onChanged: (EstadoCarrera? v) {
              if (v != null) setState(() => _estado = v);
            },
            items: EstadoCarrera.values
                .map((e) => DropdownMenuItem(value: e, child: Text(_estadoATexto(e))))
                .toList(),
            decoration: const InputDecoration(labelText: 'Estado'),
            dropdownColor: cardColor,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _seleccionarFecha,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Fecha'),
                    child: Text(
                      _fecha == null
                          ? 'Seleccionar'
                          : '${_fecha!.day}/${_fecha!.month}/${_fecha!.year}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: _seleccionarHora,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Hora'),
                    child: Text(
                      _hora == null ? 'Seleccionar' : _hora!.format(context),
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
            child: ElevatedButton(onPressed: _guardar, child: const Text('Guardar Carrera')),
          ),
        ],
      ),
    );
  }

  String _estadoATexto(EstadoCarrera e) {
    switch (e) {
      case EstadoCarrera.pendiente:
        return 'Pendiente';
      case EstadoCarrera.hecha:
        return 'Hecha';
      case EstadoCarrera.noRealizada:
        return 'No Realizada';
    }
  }
}
