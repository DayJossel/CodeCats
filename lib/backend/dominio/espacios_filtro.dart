// lib/backend/dominio/espacios_filtro.dart

import 'modelos/espacio.dart';

/// Filtro por presencia de notas en los espacios.
enum FiltroNotasEspacio { todos, conNotas, sinNotas }

/// Caso de uso: filtrar la lista de espacios según criterios de dominio
/// (nivel de seguridad y notas personales).
class FiltroEspaciosUC {
  static List<Espacio> aplicarFiltros({
    required List<Espacio> espacios,
    required Set<SeguridadEspacio> filtrosSemaforo,
    required FiltroNotasEspacio filtroNotas,
  }) {
    return espacios.where((e) {
      // 1. Filtro por Semáforo
      bool pasaFiltroSemaforo = true;
      if (filtrosSemaforo.isNotEmpty) {
        pasaFiltroSemaforo = filtrosSemaforo.contains(e.semaforo);
      }

      // 2. Filtro por Notas
      bool pasaFiltroNotas = true;
      if (filtroNotas == FiltroNotasEspacio.conNotas) {
        pasaFiltroNotas = e.notas.isNotEmpty;
      } else if (filtroNotas == FiltroNotasEspacio.sinNotas) {
        pasaFiltroNotas = e.notas.isEmpty;
      }

      return pasaFiltroSemaforo && pasaFiltroNotas;
    }).toList();
  }
}