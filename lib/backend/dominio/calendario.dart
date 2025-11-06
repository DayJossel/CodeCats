// lib/backend/dominio/calendario.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chita_app/backend/dominio/modelos/carrera.dart';
import 'package:chita_app/backend/core/notification_service.dart';

class CalendarioUC {
  static const storageKey = 'races_storage_v1';
  final String baseUrl;

  CalendarioUC({this.baseUrl = 'http://157.137.187.110:8000'});

  // ---------- Helpers ----------
  Map<String, String> authHeaders(int? corredorId, String? contrasenia) => {
        'X-Corredor-Id': '${corredorId ?? ''}',
        'X-Contrasenia': contrasenia ?? '',
      };

  bool debeTenerRecordatorio(Carrera c) =>
      c.estado == EstadoCarrera.pendiente && c.fechaHora.isAfter(DateTime.now());

  Map<DateTime, List<Carrera>> agruparEventos(List<Carrera> carreras) {
    final map = <DateTime, List<Carrera>>{};
    for (var c in carreras) {
      final d = DateTime(c.fechaHora.year, c.fechaHora.month, c.fechaHora.day);
      map.putIfAbsent(d, () => []).add(c);
    }
    return map;
  }

  // ---------- Persistencia local ----------
  Future<List<Carrera>> cargarDesdeDisco() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    final list = <Carrera>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        final List data = jsonDecode(raw) as List;
        list.addAll(data.map((e) => Carrera.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        // datos corruptos → ignorar
      }
    }
    list.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    await reprogramarRecordatoriosSilencioso(list);
    return list;
  }

  Future<void> guardarEnDisco(List<Carrera> carreras) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(carreras.map((e) => e.toJson()).toList());
    await prefs.setString(storageKey, raw);
  }

  Future<void> reprogramarRecordatoriosSilencioso(List<Carrera> carreras) async {
    for (final c in carreras) {
      if (debeTenerRecordatorio(c)) {
        await ServicioNotificaciones.instancia.programarRecordatorioCarrera(
          raceId: c.id, title: c.titulo, raceDateTimeLocal: c.fechaHora,
        );
      } else {
        await ServicioNotificaciones.instancia.cancelarRecordatorioCarrera(c.id);
      }
    }
  }

  // ---------- API ----------
  Future<List<Carrera>> listarCarrerasServidor({
    required int? corredorId,
    required String? contrasenia,
    required List<Carrera> actuales,
  }) async {
    if (corredorId == null || contrasenia == null) return actuales;

    try {
      final resp = await http.get(Uri.parse('$baseUrl/carreras'), headers: authHeaders(corredorId, contrasenia));
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body) as List;
        final servidor = data.map((e) => Carrera.fromApi(e as Map<String, dynamic>)).toList();
        final locales = actuales.where((c) => c.id < 0).toList();

        final merged = <Carrera>[...servidor, ...locales]..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
        await guardarEnDisco(merged);
        await reprogramarRecordatoriosSilencioso(merged);
        return merged;
      } else {
        // mantiene actuales
        return actuales;
      }
    } catch (_) {
      return actuales; // sin conexión → quedate con caché
    }
  }

  Future<List<Carrera>> sincronizarBorradores({
    required int? corredorId,
    required String? contrasenia,
    required List<Carrera> carreras,
  }) async {
    final drafts = carreras.where((c) => c.id < 0).toList();
    final updated = [...carreras];

    for (final local in drafts) {
      try {
        final resp = await http.post(
          Uri.parse('$baseUrl/carreras'),
          headers: {...authHeaders(corredorId, contrasenia), 'Content-Type': 'application/json'},
          body: jsonEncode(local.toApiCreateOrUpdate()),
        );
        if (resp.statusCode == 201) {
          final creada = Carrera.fromApi(jsonDecode(resp.body) as Map<String, dynamic>);
          final idx = updated.indexWhere((c) => c.id == local.id);
          if (idx != -1) updated[idx] = creada;

          await ServicioNotificaciones.instancia.cancelarRecordatorioCarrera(local.id);
          if (debeTenerRecordatorio(creada)) {
            await ServicioNotificaciones.instancia.programarRecordatorioCarrera(
              raceId: creada.id, title: creada.titulo, raceDateTimeLocal: creada.fechaHora,
            );
          }
        }
      } catch (_) {
        break; // sin conexión
      }
    }

    updated.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    await guardarEnDisco(updated);
    return updated;
  }

  Future<List<Carrera>> guardarCarrera({
    required int? corredorId,
    required String? contrasenia,
    required String titulo,
    required DateTime fechaHora,
    required EstadoCarrera estado,
    Carrera? existente,
    void Function(String msg)? onSnack,
  }) async {
    final nowFut = (existente == null) || (existente.id < 0);
    if (nowFut && !fechaHora.isAfter(DateTime.now())) {
      onSnack?.call('La carrera debe programarse en una fecha y hora futura.');
      return await cargarDesdeDisco(); // no cambia nada
    }

    // EDITAR
    if (existente != null) {
      final copia = existente.clonar();
      existente.titulo = titulo;
      existente.fechaHora = fechaHora;
      existente.estado = estado;
      existente.tzOffsetMin = DateTime.now().timeZoneOffset.inMinutes;

      // Si era local → crear en servidor
      if (existente.id < 0) {
        try {
          final resp = await http.post(
            Uri.parse('$baseUrl/carreras'),
            headers: {...authHeaders(corredorId, contrasenia), 'Content-Type': 'application/json'},
            body: jsonEncode(existente.toApiCreateOrUpdate()),
          );
          if (resp.statusCode == 201) {
            final creada = Carrera.fromApi(jsonDecode(resp.body) as Map<String, dynamic>);
            final list = await cargarDesdeDisco();
            final idx = list.indexWhere((c) => c.id == existente.id);
            if (idx != -1) list[idx] = creada;
            onSnack?.call('Carrera registrada.');

            await ServicioNotificaciones.instancia.cancelarRecordatorioCarrera(copia.id);
            if (debeTenerRecordatorio(creada)) {
              await ServicioNotificaciones.instancia.programarRecordatorioCarrera(
                raceId: creada.id, title: creada.titulo, raceDateTimeLocal: creada.fechaHora,
              );
            }
            await guardarEnDisco(list);
            return list;
          } else {
            onSnack?.call('Error (${resp.statusCode}): ${resp.body}');
            // revert local in disk
            final list = await cargarDesdeDisco();
            final idx = list.indexWhere((c) => c.id == existente.id);
            if (idx != -1) list[idx] = copia;
            await guardarEnDisco(list);
            return list;
          }
        } on SocketException catch (_) {
          onSnack?.call('Sin conexión. Cambios guardados sólo localmente.');
          final list = await cargarDesdeDisco();
          final idx = list.indexWhere((c) => c.id == existente.id);
          if (idx != -1) list[idx] = existente;
          await _aplicarPoliticaRecordatorioLocal(existente);
          await guardarEnDisco(list);
          return list;
        } on TimeoutException catch (_) {
          onSnack?.call('Sin conexión (timeout). Cambios locales.');
          final list = await cargarDesdeDisco();
          final idx = list.indexWhere((c) => c.id == existente.id);
          if (idx != -1) list[idx] = existente;
          await _aplicarPoliticaRecordatorioLocal(existente);
          await guardarEnDisco(list);
          return list;
        } on http.ClientException catch (_) {
          onSnack?.call('Sin conexión. Cambios locales.');
          final list = await cargarDesdeDisco();
          final idx = list.indexWhere((c) => c.id == existente.id);
          if (idx != -1) list[idx] = existente;
          await _aplicarPoliticaRecordatorioLocal(existente);
          await guardarEnDisco(list);
          return list;
        }
      }

      // Si ya existía en servidor → PUT
      try {
        final resp = await http.put(
          Uri.parse('$baseUrl/carreras/${existente.id}'),
          headers: {...authHeaders(corredorId, contrasenia), 'Content-Type': 'application/json'},
          body: jsonEncode(existente.toApiCreateOrUpdate()),
        );
        if (resp.statusCode == 200) {
          onSnack?.call('Carrera actualizada correctamente');
          await _aplicarPoliticaRecordatorioLocal(existente);

          final list = await cargarDesdeDisco();
          final idx = list.indexWhere((c) => c.id == existente.id);
          if (idx != -1) list[idx] = existente;
          await guardarEnDisco(list);
          return list;
        } else {
          onSnack?.call('Error (${resp.statusCode}): ${resp.body}');
          // revert in memory & disk
          final list = await cargarDesdeDisco();
          final idx = list.indexWhere((c) => c.id == existente.id);
          if (idx != -1) list[idx] = copia;
          await guardarEnDisco(list);
          return list;
        }
      } on SocketException catch (_) {
        onSnack?.call('Sin conexión. Cambios locales.');
        await _aplicarPoliticaRecordatorioLocal(existente);
        final list = await cargarDesdeDisco();
        final idx = list.indexWhere((c) => c.id == existente.id);
        if (idx != -1) list[idx] = existente;
        await guardarEnDisco(list);
        return list;
      } on TimeoutException catch (_) {
        onSnack?.call('Sin conexión (timeout). Cambios locales.');
        await _aplicarPoliticaRecordatorioLocal(existente);
        final list = await cargarDesdeDisco();
        final idx = list.indexWhere((c) => c.id == existente.id);
        if (idx != -1) list[idx] = existente;
        await guardarEnDisco(list);
        return list;
      } on http.ClientException catch (_) {
        onSnack?.call('Sin conexión. Cambios locales.');
        await _aplicarPoliticaRecordatorioLocal(existente);
        final list = await cargarDesdeDisco();
        final idx = list.indexWhere((c) => c.id == existente.id);
        if (idx != -1) list[idx] = existente;
        await guardarEnDisco(list);
        return list;
      }
    }

    // NUEVA
    try {
      final borrador = Carrera(
        id: 0,
        titulo: titulo,
        fechaHora: fechaHora,
        estado: estado,
        tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
      );
      final resp = await http.post(
        Uri.parse('$baseUrl/carreras'),
        headers: {...authHeaders(corredorId, contrasenia), 'Content-Type': 'application/json'},
        body: jsonEncode(borrador.toApiCreateOrUpdate()),
      );
      if (resp.statusCode == 201) {
        final creada = Carrera.fromApi(jsonDecode(resp.body) as Map<String, dynamic>);
        final list = await cargarDesdeDisco();
        list.add(creada);
        onSnack?.call('Carrera registrada.');
        if (debeTenerRecordatorio(creada)) {
          await ServicioNotificaciones.instancia.programarRecordatorioCarrera(
            raceId: creada.id, title: creada.titulo, raceDateTimeLocal: creada.fechaHora,
          );
        }
        list.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
        await guardarEnDisco(list);
        return list;
      } else {
        onSnack?.call('Error (${resp.statusCode}): ${resp.body}');
        return await cargarDesdeDisco();
      }
    } on SocketException catch (_) {
      final local = Carrera(
        id: -DateTime.now().millisecondsSinceEpoch,
        titulo: titulo,
        fechaHora: fechaHora,
        estado: estado,
        tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
      );
      final list = await cargarDesdeDisco();
      list.add(local);
      onSnack?.call('Sin conexión. Carrera guardada localmente.');
      if (debeTenerRecordatorio(local)) {
        await ServicioNotificaciones.instancia.programarRecordatorioCarrera(
          raceId: local.id, title: local.titulo, raceDateTimeLocal: local.fechaHora,
        );
      }
      list.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
      await guardarEnDisco(list);
      return list;
    } on TimeoutException catch (_) {
      final local = Carrera(
        id: -DateTime.now().millisecondsSinceEpoch,
        titulo: titulo,
        fechaHora: fechaHora,
        estado: estado,
        tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
      );
      final list = await cargarDesdeDisco();
      list.add(local);
      onSnack?.call('Sin conexión (timeout). Guardada localmente.');
      if (debeTenerRecordatorio(local)) {
        await ServicioNotificaciones.instancia.programarRecordatorioCarrera(
          raceId: local.id, title: local.titulo, raceDateTimeLocal: local.fechaHora,
        );
      }
      list.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
      await guardarEnDisco(list);
      return list;
    } on http.ClientException catch (_) {
      final local = Carrera(
        id: -DateTime.now().millisecondsSinceEpoch,
        titulo: titulo,
        fechaHora: fechaHora,
        estado: estado,
        tzOffsetMin: DateTime.now().timeZoneOffset.inMinutes,
      );
      final list = await cargarDesdeDisco();
      list.add(local);
      onSnack?.call('Sin conexión. Guardada localmente.');
      if (debeTenerRecordatorio(local)) {
        await ServicioNotificaciones.instancia.programarRecordatorioCarrera(
          raceId: local.id, title: local.titulo, raceDateTimeLocal: local.fechaHora,
        );
      }
      list.sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
      await guardarEnDisco(list);
      return list;
    }
  }

  Future<void> _aplicarPoliticaRecordatorioLocal(Carrera c) async {
    if (debeTenerRecordatorio(c)) {
      await ServicioNotificaciones.instancia.reprogramarRecordatorioCarrera(
        raceId: c.id, title: c.titulo, raceDateTimeLocal: c.fechaHora,
      );
    } else {
      await ServicioNotificaciones.instancia.cancelarRecordatorioCarrera(c.id);
    }
  }

  Future<List<Carrera>> actualizarEstado({
    required int? corredorId,
    required String? contrasenia,
    required Carrera carrera,
    required EstadoCarrera nuevo,
    void Function(String msg)? onSnack,
  }) async {
    final prev = carrera.estado;
    carrera.estado = nuevo;

    if (carrera.id <= 0) {
      await _aplicarPoliticaRecordatorioLocal(carrera);
      onSnack?.call('Estado guardado localmente.');
      final list = await cargarDesdeDisco();
      final idx = list.indexWhere((c) => c.id == carrera.id);
      if (idx != -1) list[idx] = carrera;
      await guardarEnDisco(list);
      return list;
    }

    try {
      final resp = await http.patch(
        Uri.parse('$baseUrl/carreras/${carrera.id}/estado?estado=${estadoCarreraToApi(nuevo)}'),
        headers: authHeaders(corredorId, contrasenia),
      );
      if (resp.statusCode == 200) {
        onSnack?.call('Estado de la carrera actualizado.');
        await _aplicarPoliticaRecordatorioLocal(carrera);
      } else {
        carrera.estado = prev;
        onSnack?.call('Error (${resp.statusCode}): ${resp.body}');
      }
    } on SocketException catch (_) {
      onSnack?.call('Sin conexión. Estado guardado sólo localmente.');
      await _aplicarPoliticaRecordatorioLocal(carrera);
    } on TimeoutException catch (_) {
      onSnack?.call('Sin conexión (timeout). Estado local.');
      await _aplicarPoliticaRecordatorioLocal(carrera);
    } on http.ClientException catch (_) {
      onSnack?.call('Sin conexión. Estado local.');
      await _aplicarPoliticaRecordatorioLocal(carrera);
    }

    final list = await cargarDesdeDisco();
    final idx = list.indexWhere((c) => c.id == carrera.id);
    if (idx != -1) list[idx] = carrera;
    await guardarEnDisco(list);
    return list;
  }

  Future<List<Carrera>> eliminarCarrera({
    required int? corredorId,
    required String? contrasenia,
    required Carrera carrera,
    void Function(String msg)? onSnack,
  }) async {
    await ServicioNotificaciones.instancia.cancelarRecordatorioCarrera(carrera.id);

    if (carrera.id > 0) {
      try {
        final resp = await http.delete(Uri.parse('$baseUrl/carreras/${carrera.id}'),
            headers: authHeaders(corredorId, contrasenia));
        if (resp.statusCode != 200) {
          onSnack?.call('Error al eliminar (${resp.statusCode}): ${resp.body}');
          return await cargarDesdeDisco();
        }
      } on SocketException catch (_) {
        onSnack?.call('Sin conexión. No se pudo eliminar en servidor.');
        return await cargarDesdeDisco();
      } on TimeoutException catch (_) {
        onSnack?.call('Sin conexión (timeout). No se pudo eliminar en servidor.');
        return await cargarDesdeDisco();
      } on http.ClientException catch (_) {
        onSnack?.call('Sin conexión. No se pudo eliminar en servidor.');
        return await cargarDesdeDisco();
      }
    }

    final list = await cargarDesdeDisco();
    list.removeWhere((r) => r.id == carrera.id);
    await guardarEnDisco(list);
    onSnack?.call('Carrera eliminada.');
    return list;
  }
}
