// lib/backend/dominio/modelos/contacto.dart

class Contacto {
  final int id;
  final String nombre;
  final String telefono; // ya normalizado a 10 dígitos
  final String relacion;

  const Contacto({
    required this.id,
    required this.nombre,
    required this.telefono,
    required this.relacion,
  });

  factory Contacto.fromApi(Map<String, dynamic> j) {
    return Contacto(
      id: (j['contacto_id'] as num).toInt(),
      nombre: (j['nombre'] as String?)?.trim() ?? 'Contacto',
      telefono: (j['telefono'] as String?)?.trim() ?? '',
      relacion: (j['relacion'] as String?)?.trim().isNotEmpty == true
          ? (j['relacion'] as String).trim()
          : 'N/A',
    );
  }

  Map<String, dynamic> toApi() => {
        'nombre': nombre,
        'telefono': telefono,
        'relacion': relacion,
      };
}
