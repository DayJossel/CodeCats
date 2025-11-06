// lib/backend/dominio/modelos/corredor.dart
class CorredorPerfil {
  final int corredorId;
  final String nombre;
  final String correo;
  final String telefono;

  const CorredorPerfil({
    required this.corredorId,
    required this.nombre,
    required this.correo,
    required this.telefono,
  });

  factory CorredorPerfil.fromApi(Map<String, dynamic> j) {
    return CorredorPerfil(
      corredorId: (j['corredor_id'] as num?)?.toInt() ?? (j['id'] as num?)?.toInt() ?? 0,
      nombre: (j['nombre'] as String?)?.trim() ?? '',
      correo: (j['correo'] as String?)?.trim() ?? '',
      telefono: (j['telefono'] as String?)?.trim() ?? '',
    );
  }
}
