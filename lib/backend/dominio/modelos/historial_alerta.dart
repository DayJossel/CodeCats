// lib/backend/dominio/modelos/historial_alerta.dart
class HistorialAlerta {
  final int id;
  final DateTime fecha;      // Se parsea desde ISO (UTC o local)
  final String? mensaje;     // Opcional, por si el backend lo envía

  HistorialAlerta({
    required this.id,
    required this.fecha,
    this.mensaje,
  });

  static HistorialAlerta fromApi(Map<String, dynamic> j) {
    final id = (j['historial_id'] as num).toInt();
    final fechaRaw = (j['fecha']?.toString() ?? '');
    final fecha = DateTime.tryParse(fechaRaw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return HistorialAlerta(
      id: id,
      fecha: fecha,
      mensaje: j['mensaje']?.toString(),
    );
  }
}
