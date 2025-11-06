// lib/backend/dominio/modelos/estadistica.dart

class EstadisticaMensual {
  final int year;
  final int month;

  final int? objetivo;        // puede venir null
  final int total;
  final int hechas;
  final int pendientes;
  final int noRealizadas;
  final bool? cumpleObjetivo; // puede venir null

  /// true si los datos provienen del respaldo local (sin objetivo ni verificación de "cumple")
  final bool fromLocal;

  const EstadisticaMensual({
    required this.year,
    required this.month,
    required this.total,
    required this.hechas,
    required this.pendientes,
    required this.noRealizadas,
    this.objetivo,
    this.cumpleObjetivo,
    this.fromLocal = false,
  });

  factory EstadisticaMensual.fromApi(Map<String, dynamic> j, {required int year, required int month}) {
    return EstadisticaMensual(
      year: year,
      month: month,
      objetivo: j['objetivo'] as int?,
      total: (j['total'] as num).toInt(),
      hechas: (j['hechas'] as num).toInt(),
      pendientes: (j['pendientes'] as num).toInt(),
      noRealizadas: (j['no_realizadas'] as num).toInt(),
      cumpleObjetivo: j['cumple_objetivo'] as bool?,
      fromLocal: false,
    );
  }
}
