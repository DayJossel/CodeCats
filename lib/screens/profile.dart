// lib/screens/profile.dart
import 'package:flutter/material.dart';
import 'login.dart';
import '../main.dart';

import '../backend/dominio/profile.dart';
import '../backend/dominio/modelos/corredor.dart';

class PantallaPerfil extends StatefulWidget {
  const PantallaPerfil({super.key});

  @override
  State<PantallaPerfil> createState() => EstadoPantallaPerfil();
}

// Compatibilidad
class ProfileScreen extends PantallaPerfil {
  const ProfileScreen({super.key});
}

class EstadoPantallaPerfil extends State<PantallaPerfil> {
  bool _cargando = true;
  String? _error;
  CorredorPerfil? _perfil;

  bool _editando = false;
  bool _guardando = false;

  // Controladores para edición
  final TextEditingController _nombreCtrl = TextEditingController();
  final TextEditingController _correoCtrl = TextEditingController();
  final TextEditingController _telefonoCtrl = TextEditingController();

  String? _errorNombre;
  String? _errorCorreo;
  String? _errorTelefono;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final ok = await ProfileUC.tieneSesion();
      if (!ok) {
        setState(() {
          _cargando = false;
          _error = 'No hay sesión activa.';
        });
        return;
      }
      final p = await ProfileUC.cargarPerfil();
      setState(() {
        _perfil = p;
        _cargando = false;
        // Inicializar controllers con los datos actuales
        _nombreCtrl.text = p.nombre;
        _correoCtrl.text = p.correo;
        _telefonoCtrl.text = p.telefono;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _cerrarSesion() async {
    await ProfileUC.cerrarSesion();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  Future<void> _eliminarCuenta() async {
    try {
      await ProfileUC.eliminarCuenta();
      await ProfileUC.cerrarSesion();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta eliminada exitosamente')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _confirmarEliminar() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Eliminar cuenta?',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Esta acción es permanente y no se puede deshacer.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _eliminarCuenta();
                },
                child: const Text('Eliminar Cuenta', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _entrarModoEdicion() {
    if (_perfil == null) return;
    setState(() {
      _editando = true;
      _errorNombre = null;
      _errorCorreo = null;
      _errorTelefono = null;
      // Refrescar controllers desde el modelo por si se recargó
      _nombreCtrl.text = _perfil!.nombre;
      _correoCtrl.text = _perfil!.correo;
      _telefonoCtrl.text = _perfil!.telefono;
    });
  }

  void _cancelarEdicion() {
    setState(() {
      _editando = false;
      _errorNombre = null;
      _errorCorreo = null;
      _errorTelefono = null;
    });
  }

  Future<void> _guardarCambios() async {
    if (_perfil == null || _guardando) return;

    final nombre = _nombreCtrl.text.trim();
    final correo = _correoCtrl.text.trim();
    final telefono = _telefonoCtrl.text.trim();

    String? eNom;
    String? eCor;
    String? eTel;

    // Validaciones básicas (flujo 4A)
    if (nombre.isEmpty) {
      eNom = 'El nombre no puede estar vacío.';
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (correo.isEmpty) {
      eCor = 'El correo no puede estar vacío.';
    } else if (!emailRegex.hasMatch(correo)) {
      eCor = 'El formato de correo no es válido.';
    }

    final soloDigitos = telefono.replaceAll(RegExp(r'\D'), '');
    if (soloDigitos.length < 8) {
      eTel = 'El teléfono debe tener al menos 8 dígitos.';
    }

    setState(() {
      _errorNombre = eNom;
      _errorCorreo = eCor;
      _errorTelefono = eTel;
    });

    // Si hay errores, no llamamos al API (se queda en flujo 4A)
    if (eNom != null || eCor != null || eTel != null) {
      return;
    }

    // Llamada al API (flujo 4–6)
    setState(() {
      _guardando = true;
    });

    try {
      final perfilActualizado = await ProfileUC.actualizarPerfil(
        nombre: nombre,
        correo: correo,
        telefono: telefono,
      );

      if (!mounted) return;

      setState(() {
        _perfil = perfilActualizado;
        _editando = false;
        _guardando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente')),
      );
    } catch (e) {
      // Flujo de excepción 4E: fallo al guardar cambios
      if (!mounted) return;
      setState(() {
        _guardando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No fue posible guardar los cambios. Intenta de nuevo más tarde.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _bootstrap,
                    child: const Text('Reintentar'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _cerrarSesion,
                    child: const Text('Volver a iniciar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final p = _perfil!;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          children: [
            // Cabecera con correo y botón de edición/guardar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    p.correo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                if (!_editando)
                  TextButton(
                    onPressed: _entrarModoEdicion,
                    child: const Text('Editar'),
                  )
                else
                  TextButton(
                    onPressed: _guardando ? null : _guardarCambios,
                    child: _guardando
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                          )
                        : const Text('Guardar'),
                  ),
              ],
            ),
            const SizedBox(height: 30),
            const _TituloSeccion(titulo: 'Información Personal'),
            const SizedBox(height: 16),

            // Nombre
            if (_editando)
              _CampoEditable(
                etiqueta: 'Nombre Completo',
                controller: _nombreCtrl,
                errorText: _errorNombre,
              )
            else
              _InfoTile(etiqueta: 'Nombre Completo', valor: p.nombre),
            const SizedBox(height: 16),

            // Email
            if (_editando)
              _CampoEditable(
                etiqueta: 'Email',
                controller: _correoCtrl,
                teclado: TextInputType.emailAddress,
                errorText: _errorCorreo,
              )
            else
              _InfoTile(etiqueta: 'Email', valor: p.correo),
            const SizedBox(height: 16),

            // Teléfono
            if (_editando)
              _CampoEditable(
                etiqueta: 'Número de Teléfono',
                controller: _telefonoCtrl,
                teclado: TextInputType.phone,
                errorText: _errorTelefono,
              )
            else
              _InfoTile(etiqueta: 'Número de Teléfono', valor: p.telefono),

            const SizedBox(height: 24),

            if (_editando)
              TextButton(
                onPressed: _guardando ? null : _cancelarEdicion,
                child: const Text(
                  'Cancelar edición',
                  style: TextStyle(color: Colors.grey),
                ),
              ),

            const SizedBox(height: 30),
            const _TituloSeccion(titulo: 'Cuenta'),
            const SizedBox(height: 16),
            _BotonAccionCuenta(
              texto: 'Cerrar Sesión',
              icono: Icons.logout,
              onTap: _cerrarSesion,
            ),
            const SizedBox(height: 16),
            _BotonAccionCuenta(
              texto: 'Eliminar Cuenta',
              icono: Icons.delete_outline,
              colorTexto: accentColor,
              onTap: _confirmarEliminar,
            ),
          ],
        ),
      ),
    );
  }
}

// Reutilizables locales (privados)
class _TituloSeccion extends StatelessWidget {
  final String titulo;
  const _TituloSeccion({required this.titulo});

  @override
  Widget build(BuildContext context) => Text(
        titulo,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      );
}

class _InfoTile extends StatelessWidget {
  final String etiqueta;
  final String valor;
  const _InfoTile({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              valor,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      );
}

class _CampoEditable extends StatelessWidget {
  final String etiqueta;
  final TextEditingController controller;
  final TextInputType teclado;
  final String? errorText;

  const _CampoEditable({
    required this.etiqueta,
    required this.controller,
    this.teclado = TextInputType.text,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: teclado,
            decoration: InputDecoration(
              filled: true,
              fillColor: cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: errorText == null ? Colors.transparent : Colors.red,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: errorText == null ? primaryColor : Colors.red,
                ),
              ),
              errorText: errorText,
            ),
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      );
}

class _BotonAccionCuenta extends StatelessWidget {
  final String texto;
  final IconData icono;
  final VoidCallback onTap;
  final Color colorTexto;

  const _BotonAccionCuenta({
    required this.texto,
    required this.icono,
    required this.onTap,
    this.colorTexto = Colors.white,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: colorTexto != Colors.white
                ? Border.all(color: cardColor)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, color: colorTexto, size: 22),
              const SizedBox(width: 8),
              Text(
                texto,
                style: TextStyle(
                  color: colorTexto,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
}
