// lib/backend/dominio/modelos/carrera.dart
import 'package:flutter/material.dart';

enum EstadoCarrera { pendiente, hecha, noRealizada }

String estadoCarreraToApi(EstadoCarrera s) {
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

EstadoCarrera estadoCarreraFromApi(String s) {
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
      estado: estadoCarreraFromApi(m['estado'] as String),
      tzOffsetMin: (m['tz_offset_min'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toApiCreateOrUpdate() => {
        'titulo': titulo,
        'fecha_hora_utc': fechaHora.toUtc().toIso8601String(),
        'tz_offset_min': DateTime.now().timeZoneOffset.inMinutes,
        'estado': estadoCarreraToApi(estado),
      };

  Carrera clonar() => Carrera(
        id: id,
        titulo: titulo,
        fechaHora: fechaHora,
        estado: estado,
        tzOffsetMin: tzOffsetMin,
      );
}
