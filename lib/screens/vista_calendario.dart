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

import '../main.dart';
import '../backend/core/notification_service.dart'; // Usaremos ServicioNotificaciones (alias)

const String _baseUrl = 'http://157.137.187.110:8000';

String _fmt(DateTime dt) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
}

// =============================
// Modelo / utilidades de estado
// =============================
enum EstadoCarrera { pendiente, hecha, noRealizada }

String _estadoAApi(EstadoCarrera s) {
  switch (s) {
    case EstadoCarrera.hecha:
      return 'hecha';
    case EstadoCarrera.noRealizada:
      return 'no_realizada';
    case EstadoCarrera.pendiente:
    default:
      return 'pendiente';
  }
}

EstadoCarrera _estadoDesdeApi(String s) {
  switch (s) {
    case 'hecha':
      return EstadoCarrera.hecha;
    case 'no_realizada':
      return EstadoCarrera.noRealizada;
    case 'pendiente':
    default:
      return EstadoCarrera.pendiente;
  }
}

class Carrera {
  int id;                // id>0 servidor, id<0 local/offline
  String titulo;
  DateTime fechaHora;    // hora local (UI)
  EstadoCarrera estado;
  int tzOffsetMin;

  Carrera({
    required this.id,
    required this.titulo,
    required this.fechaHora,
    this.estado = EstadoCarrera.pendiente,
    this.tzOffsetMin = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'fechaHora': fechaHora.toIso8601String(),
        'estado': estado.index,
        'tzOffsetMin': tzOffsetMin,
      };

  static Carrera fromJson(Map<String, dynamic> m) => Carrera(
        id: m['id'] as int,
        titulo: m['titulo'] as String,
        fechaHora: DateTime.parse(m['fechaHora'] as String),
        estado: EstadoCarrera.values[(m['estado'] as int?) ?? 0],
        tzOffsetMin: (m['tzOffsetMin'] as int?) ?? 0,
      );

  static Carrera fromApi(Map<String, dynamic> m) {
    final utc = DateTime.parse(m['fecha_hora_utc'] as String).toUtc();
    return Carrera(
      id: m['carrera_id'] as int,
      titulo: m['titulo'] as String,
      fechaHora: utc.toLocal(),
      estado: _estadoDesdeApi(m['estado'] as String),
      tzOffsetMin: (m['tz_offset_min'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toApiCreateOrUpdate() => {
        'titulo': titulo,
        'fecha_hora_utc': fechaHora.toUtc().toIso8601String(),
        'tz_offset_min': DateTime.now().timeZoneOffset.inMinutes,
        'estado': _estadoAApi(estado),
      };

  Carrera clonar() => Carrera(
        id: id,
        titulo: titulo,
        fechaHora: fechaHora,
        estado: estado,
        tzOffsetMin: tzOffsetMin,
      );
}

// =============================
// Vista principal
// =============================
class VistaCalendario extends StatefulWidget {
  const VistaCalendario({super.key});

  @override
  State<VistaCalendario> createState() => EstadoVistaCalendario();
}

class EstadoVistaCalendario extends State<VistaCalendario> {
  final List<Carrera> _carreras = [];
  late DateTime _diaEnfocado;
  late DateTime _diaSeleccionado;
  late CalendarFormat _formatoCalendario;
  Map<DateTime, List<Carrera>> _eventos = {};

  static const _claveStorage = 'races_storage_v1';

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
    _cargarDesdeDisco();     // pinta caché
    _cargarUsuario();        // luego servidor + sync
  }

  // =============================
  // Usuario / Auth
  // =============================
  Future<void> _cargarUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    corredorId = prefs.getInt('corredor_id');
    contrasenia = prefs.getString('contrasenia');

    setState(() => _usuarioCargado = true);

    if (corredorId != null && contrasenia != null) {
      await _listarCarrerasServidor();
      await _sincronizarBorradores();
    }
  }

  Map<String, String> _encabezadosAuth() => {
        'X-Corredor-Id': '${corredorId ?? ''}',
        'X-Contrasenia': contrasenia ?? '',
      };

  bool _debeTenerRecordatorio(Carrera c) =>
      c.estado == EstadoCarrera.pendiente && c.fechaHora.isAfter(DateTime.now());

  // =============================
  // Persistencia local
  // =============================
  Future<void> _cargarDesdeDisco() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_claveStorage);
    _carreras.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        final List list = jsonDecode(raw) as List;
        _carreras.addAll(list.map((e) => Carrera.fromJson(e as Map<String, dynamic>)));
      } catch (_) {/* datos corruptos: ignora */}
    }
    _carreras.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    _agruparEventos();
    await _reprogramarRecordatoriosSilencioso();
    if (mounted) setState(() {});
  }

  Future<void> _guardarEnDisco() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_carreras.map((e) => e.toJson()).toList());
    await prefs.setString(_claveStorage, raw);
  }

  void _agruparEventos() {
    _eventos = {};
    for (var c in _carreras) {
      final d = DateTime(c.fechaHora.year, c.fechaHora.month, c.fechaHora.day);
      _eventos.putIfAbsent(d, () => []).add(c);
    }
  }

  List<Carrera> _eventosDelDia(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return _eventos[d] ?? [];
  }

  Future<void> _reprogramarRecordatoriosSilencioso() async {
    for (final c in _carreras) {
      if (_debeTenerRecordatorio(c)) {
        await ServicioNotificaciones.instancia.programarRecordatorioCarrera(
          raceId: c.id, title: c.titulo, raceDateTimeLocal: c.fechaHora,
        );
      } else {
        await ServicioNotificaciones.instancia.cancelarRecordatorioCarrera(c.id);
      }
    }
  }

  // =============================
  // API: listar / crear / actualizar / eliminar
  // =============================
  Future<void> _listarCarrerasServidor() async {
    if (corredorId == null || contrasenia == null) return;
    setState(() => _cargando = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/carreras'), headers: _encabezadosAuth());
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body) as List;
        final servidor = data.map((e) => Carrera.fromApi(e as Map<String, dynamic>)).toList();
        final locales = _carreras.where((c) => c.id < 0).toList();

        _carreras..clear()..addAll(servidor)..addAll(locales);
        _carreras.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
        _agruparEventos();
        await _guardarEnDisco();
        await _reprogramarRecordatoriosSilencioso();
        setState(() {});
      } else {
        _mostrarSnack('Error al obtener carreras (${response.statusCode}): ${response.body}');
      }
    } catch (_) {
      // sin internet: queda caché
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _sincronizarBorradores() async {
    final drafts = _carreras.where((c) => c.id < 0).toList();
    for (final local in drafts) {
      try {
        final resp = await http.post(
          Uri.parse('$_baseUrl/carreras'),
          headers: {..._encabezadosAuth(), 'Content-Type': 'application/json'},
          body: jsonEncode(local.toApiCreateOrUpdate()),
        );
        if (resp.statusCode == 201) {
          final creada = Carrera.fromApi(jsonDecode(resp.body) as Map<String, dynamic>);
          final idx = _carreras.indexWhere((c) => c.id == local.id);
          if (idx != -1) _carreras[idx] = creada;

          await ServicioNotificaciones.instancia.cancelarRecordatorioCarrera(local.id);
          if (_debeTenerRecordatorio(creada)) {
            await ServicioNotificaciones.instancia.programarRecordatorioCarrera(
              raceId: creada.id, title: creada.titulo, raceDateTimeLocal: creada.fechaHora,
            );
          }
        }
      } catch (_) {
        break; // sin conexión: corto
      }
    }
    _carreras.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    _agruparEventos();
    await _guardarEnDisco();
    if (mounted) setState(() {});
  }

  // =============================
  // Acciones UI
  // =============================
  void _mostrarSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _guardarCarrera(String titulo, DateTime fechaHora, EstadoCarrera estado,
      {Carrera? existente}) async {
    final debeSerFutura = (existente == null) || (existente.id < 0);
    if (debeSerFutura && !fechaHora.isAfter(DateTime.now())) {
      _mostrarSnack('La carrera debe programarse en una fecha y hora futura.');
      return;
    }

    // EDITAR
    if (existente != null) {
      final copia = existente.clonar();
      existente.titulo = titulo;
      existente.fechaHora = fechaHora;
      existente.estado = estado;
      existente.tzOffsetMin = DateTime.now().timeZoneOffset.inMinutes;

      if (existente.id < 0) {
        try {
          final resp = await http.post(
            Uri.parse('$_baseUrl/carreras'),
            headers: {..._encabezadosAuth(), 'Content-Type': 'application/json'},
            body: jsonEncode(existente.toApiCreateOrUpdate()),
          );
          if (resp.statusCode == 201) {
            final creada = Carrera.fromApi(jsonDecode(resp.body) as Map<String, dynamic>);
            final idx = _carreras.indexWhere((c) => c.id == existente.id);
            if (idx != -1) _carreras[idx] = creada;
            _mostrarSnack('Carrera registrada.');

            await ServicioNotificaciones.instancia.cancelarRecordatorioCarrera(copia.id);
            if (_debeTenerRecordatorio(creada)) {
              await ServicioNotificaciones.instancia.programarRecordatorioCarrera(
                raceId: creada.id, title: creada.titulo, raceDateTimeLocal: creada.fechaHora,
              );
              _mostrarSnack('Recordatorio: ${_fmt(creada.fechaHora.subtract(const Duration(hours: 2)))}');
            }
          } else {
            final idx = _carreras.indexWhere((c) => c.id == existente.id);
            if (idx != -1) _carreras[idx] = copia;
            _mostrarSnack('Error (${resp.statusCode}): ${resp.body}');
          }
        } on SocketException catch (_) {
          _mostrarSnack('Sin conexión. Cambios guardados sólo localmente.');
        } on TimeoutException catch (_) {
          _mostrarSnack('Sin conexión (timeout). Cambios locales.');
        } on http.ClientException catch (_) {
          _mostrarSnack('Sin conexión. Cambios locales.');
        }
      } else {
        try {
          final resp = await http.put(
            Uri.parse('$_baseUrl/carreras/${existente.id}'),
            headers: {..._encabezadosAuth(), 'Content-Type': 'application/json'},
            body: jsonEncode(existente.toApiCreateOrUpdate()),
          );
          if (resp.statusCode == 200) {
            _mostrarSnack('Carrera actualizada correctamente');
            if (_debeTenerRecordatorio(existente)) {
              await ServicioNotificaciones.instancia.reprogramarRecordatorioCarrera(
                raceId: existente.id, title: existente.titulo, raceDateTimeLocal: existente.fechaHora,
              );
              _mostrarSnack('Recordatorio reprogramado: ${_fmt(existente.fechaHora.subtract(const Duration(hours: 2)))}');
            } else {
              await ServicioNotificaciones.instancia.cancelarRecordatorioCarrera(existente.id);
            }
          } else {
            existente.titulo = copia.titulo;
            existente.fechaHora = copia.fechaHora;
            existente.estado = copia.estado;
            existente.tzOffsetMin = copia.tzOffsetMin;
            _mostrarSnack('Error (${resp.statusCode}): ${resp.body}');
          }
        } on SocketException catch (_) {
          _mostrarSnack('Sin conexión. Cambios locales.');
          await _aplicarPoliticaRecordatorioLocal(existente);
        } on TimeoutException catch (_) {
          _mostrarSnack('Sin conexión (timeout). Cambios locales.');
          await _aplicarPoliticaRecordatorioLocal(existente);
        } on http.ClientException catch (_) {
          _mostrarSnack('Sin conexión. Cambios locales.');
          await _aplicarPoliticaRecordatorioLocal(existente);
        }
      }
    }
    // NUEVA
    else {
      try {
        final borrador = Carrera(
          id: 0,
          titulo: titulo,
          fechaHora: fechaHora,
          estado: estado,
          tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
        );
        final resp = await http.post(
          Uri.parse('$_baseUrl/carreras'),
          headers: {..._encabezadosAuth(), 'Content-Type': 'application/json'},
          body: jsonEncode(borrador.toApiCreateOrUpdate()),
        );
        if (resp.statusCode == 201) {
          final creada = Carrera.fromApi(jsonDecode(resp.body) as Map<String, dynamic>);
          _carreras.add(creada);
          _mostrarSnack('Carrera registrada.');
          if (_debeTenerRecordatorio(creada)) {
            await ServicioNotificaciones.instancia.programarRecordatorioCarrera(
              raceId: creada.id, title: creada.titulo, raceDateTimeLocal: creada.fechaHora,
            );
            _mostrarSnack('Recordatorio: ${_fmt(creada.fechaHora.subtract(const Duration(hours: 2)))}');
          }
        } else {
          _mostrarSnack('Error (${resp.statusCode}): ${resp.body}');
        }
      } on SocketException catch (_) {
        final local = Carrera(
          id: -DateTime.now().millisecondsSinceEpoch,
          titulo: titulo,
          fechaHora: fechaHora,
          estado: estado,
          tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
        );
        _carreras.add(local);
        _mostrarSnack('Sin conexión. Carrera guardada localmente.');
        if (_debeTenerRecordatorio(local)) {
          await ServicioNotificaciones.instancia.programarRecordatorioCarrera(
            raceId: local.id, title: local.titulo, raceDateTimeLocal: local.fechaHora,
          );
          _mostrarSnack('Recordatorio (offline): ${_fmt(local.fechaHora.subtract(const Duration(hours: 2)))}');
        }
      } on TimeoutException catch (_) {
        final local = Carrera(
          id: -DateTime.now().millisecondsSinceEpoch,
          titulo: titulo,
          fechaHora: fechaHora,
          estado: estado,
          tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
        );
        _carreras.add(local);
        _mostrarSnack('Sin conexión (timeout). Guardada localmente.');
        if (_debeTenerRecordatorio(local)) {
          await ServicioNotificaciones.instancia.programarRecordatorioCarrera(
            raceId: local.id, title: local.titulo, raceDateTimeLocal: local.fechaHora,
          );
          _mostrarSnack('Recordatorio (offline): ${_fmt(local.fechaHora.subtract(const Duration(hours: 2)))}');
        }
      } on http.ClientException catch (_) {
        final local = Carrera(
          id: -DateTime.now().millisecondsSinceEpoch,
          titulo: titulo,
          fechaHora: fechaHora,
          estado: estado,
          tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
        );
        _carreras.add(local);
        _mostrarSnack('Sin conexión. Guardada localmente.');
        if (_debeTenerRecordatorio(local)) {
          await ServicioNotificaciones.instancia.programarRecordatorioCarrera(
            raceId: local.id, title: local.titulo, raceDateTimeLocal: local.fechaHora,
          );
          _mostrarSnack('Recordatorio (offline): ${_fmt(local.fechaHora.subtract(const Duration(hours: 2)))}');
        }
      }
    }

    _carreras.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    _agruparEventos();
    await _guardarEnDisco();
    if (mounted) setState(() {});
  }

  Future<void> _aplicarPoliticaRecordatorioLocal(Carrera c) async {
    if (_debeTenerRecordatorio(c)) {
      await ServicioNotificaciones.instancia.reprogramarRecordatorioCarrera(
        raceId: c.id, title: c.titulo, raceDateTimeLocal: c.fechaHora,
      );
    } else {
      await ServicioNotificaciones.instancia.cancelarRecordatorioCarrera(c.id);
    }
  }

  Future<void> _actualizarEstado(Carrera c, EstadoCarrera nuevo) async {
    final prev = c.estado;
    c.estado = nuevo;

    if (c.id <= 0) {
      await _aplicarPoliticaRecordatorioLocal(c);
      _mostrarSnack('Estado guardado localmente.');
      await _guardarEnDisco();
      if (mounted) setState(() {});
      return;
    }

    try {
      final resp = await http.patch(
        Uri.parse('$_baseUrl/carreras/${c.id}/estado?estado=${_estadoAApi(nuevo)}'),
        headers: _encabezadosAuth(),
      );
      if (resp.statusCode == 200) {
        _mostrarSnack('Estado de la carrera actualizado.');
        await _aplicarPoliticaRecordatorioLocal(c);
      } else {
        c.estado = prev;
        _mostrarSnack('Error (${resp.statusCode}): ${resp.body}');
      }
    } on SocketException catch (_) {
      _mostrarSnack('Sin conexión. Estado guardado sólo localmente.');
      await _aplicarPoliticaRecordatorioLocal(c);
    } on TimeoutException catch (_) {
      _mostrarSnack('Sin conexión (timeout). Estado local.');
      await _aplicarPoliticaRecordatorioLocal(c);
    } on http.ClientException catch (_) {
      _mostrarSnack('Sin conexión. Estado local.');
      await _aplicarPoliticaRecordatorioLocal(c);
    }

    await _guardarEnDisco();
    if (mounted) setState(() {});
  }

  Future<void> _eliminarCarrera(Carrera c) async {
    await ServicioNotificaciones.instancia.cancelarRecordatorioCarrera(c.id);

    if (c.id > 0) {
      try {
        final resp = await http.delete(Uri.parse('$_baseUrl/carreras/${c.id}'), headers: _encabezadosAuth());
        if (resp.statusCode != 200) {
          _mostrarSnack('Error al eliminar (${resp.statusCode}): ${resp.body}');
          return;
        }
      } on SocketException catch (_) {
        _mostrarSnack('Sin conexión. No se pudo eliminar en servidor.');
        return;
      } on TimeoutException catch (_) {
        _mostrarSnack('Sin conexión (timeout). No se pudo eliminar en servidor.');
        return;
      } on http.ClientException catch (_) {
        _mostrarSnack('Sin conexión. No se pudo eliminar en servidor.');
        return;
      }
    }

    _carreras.removeWhere((r) => r.id == c.id);
    _agruparEventos();
    await _guardarEnDisco();
    if (mounted) setState(() {});
    _mostrarSnack('Carrera eliminada.');
  }

  void _confirmarEliminar(Carrera c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar carrera"),
        content: const Text("¿Seguro que deseas eliminar esta carrera?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(onPressed: () async { Navigator.pop(ctx); await _eliminarCarrera(c); },
              child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  // =============================
  // Build
  // =============================
  @override
  Widget build(BuildContext context) {
    if (!_usuarioCargado) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: primaryColor)));
    }

    final eventosDelSeleccionado = _eventosDelDia(_diaSeleccionado);

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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
          child: FloatingActionButton.small(
            onPressed: () => _mostrarFormulario(diaSeleccionado: _diaSeleccionado),
            backgroundColor: primaryColor,
            foregroundColor: Colors.black,
            child: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  Widget _construirCalendario() {
    return TableCalendar<Carrera>(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _diaEnfocado,
      calendarFormat: _formatoCalendario,
      selectedDayPredicate: (day) => isSameDay(_diaSeleccionado, day),
      eventLoader: _eventosDelDia,
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
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
                    onPressed: () { setState(() => _hora = tmp); Navigator.of(ctx).pop(); },
                    child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: DateTime(
                  DateTime.now().year, DateTime.now().month, DateTime.now().day,
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
    final full = DateTime(_fecha!.year, _fecha!.month, _fecha!.day, _hora!.hour, _hora!.minute);
    widget.onSave(titulo, full, _estado);
    Navigator.of(context).pop();
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
            onChanged: (EstadoCarrera? v) { if (v != null) setState(() => _estado = v); },
            items: EstadoCarrera.values.map((e) => DropdownMenuItem(value: e, child: Text(_estadoATexto(e)))).toList(),
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
                      _fecha == null ? 'Seleccionar'
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
      case EstadoCarrera.pendiente: return 'Pendiente';
      case EstadoCarrera.hecha: return 'Hecha';
      case EstadoCarrera.noRealizada: return 'No Realizada';
    }
  }
}
