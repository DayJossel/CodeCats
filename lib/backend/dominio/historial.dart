// lib/backend/dominio/historial.dart
import '../data/api_service.dart';
import 'modelos/historial_alerta.dart';

class HistorialUC {
  /// Lista historial desde backend y lo devuelve ordenado por fecha desc.
  static Future<List<HistorialAlerta>> listarOrdenadoDesc() async {
    final list = await ServicioApi.listarHistorial(); // espera: List<Map<String,dynamic>>
    final parsed = list.map<HistorialAlerta>(HistorialAlerta.fromApi).toList();
    parsed.sort((a, b) => b.fecha.compareTo(a.fecha));
    return parsed;
  }
}
