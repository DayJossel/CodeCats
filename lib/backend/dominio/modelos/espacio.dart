// lib/backend/dominio/modelos/espacio.dart

enum SeguridadEspacio { ninguno, inseguro, parcialmenteSeguro, seguro }

class NotaEspacio {
  final int id;
  final int espacioId;
  String contenido;

  NotaEspacio({required this.id, required this.espacioId, required this.contenido});

  factory NotaEspacio.fromApi(Map<String, dynamic> j) => NotaEspacio(
        id: (j['nota_id'] as num).toInt(),
        espacioId: (j['espacio_id'] as num).toInt(),
        contenido: (j['contenido'] as String? ?? '').trim(),
      );

  Map<String, dynamic> toApiUpdate() => {'contenido': contenido};
}

class Espacio {
  final int? espacioId;
  final int? corredorId;
  final String nombre;
  final String? enlace; // Link a Maps o lat,lng canónico
  SeguridadEspacio semaforo;
  List<NotaEspacio> notas;

  Espacio({
    required this.nombre,
    this.enlace,
    this.espacioId,
    this.corredorId,
    this.semaforo = SeguridadEspacio.ninguno,
    List<NotaEspacio>? notas,
  }) : notas = notas ?? [];

  static SeguridadEspacio _semaforoDesdeDb(int? n) {
    if (n == null) return SeguridadEspacio.ninguno;
    switch (n) {
      case 0: return SeguridadEspacio.inseguro;
      case 1: return SeguridadEspacio.parcialmenteSeguro;
      case 2: return SeguridadEspacio.seguro;
      default: return SeguridadEspacio.ninguno;
    }
  }

  factory Espacio.fromApi(Map<String, dynamic> j) {
    final nombre = (j['nombreEspacio'] as String?)?.trim() ?? 'Sin nombre';
    return Espacio(
      espacioId: (j['espacio_id'] as num?)?.toInt(),
      corredorId: (j['corredor_id'] as num?)?.toInt(),
      nombre: nombre,
      enlace: (j['enlaceUbicacion'] as String?)?.trim(),
      semaforo: _semaforoDesdeDb((j['semaforo'] as num?)?.toInt()),
    );
  }
}