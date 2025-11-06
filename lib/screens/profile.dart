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

  @override
  void initState() {
    super.initState();
    _bootstrap();
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
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
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _bootstrap, child: const Text('Reintentar')),
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          children: [
            Center(
              child: Text(
                p.correo,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),
            const _TituloSeccion(titulo: 'Información Personal'),
            const SizedBox(height: 16),
            _InfoTile(etiqueta: 'Nombre Completo', valor: p.nombre),
            const SizedBox(height: 16),
            _InfoTile(etiqueta: 'Email', valor: p.correo),
            const SizedBox(height: 16),
            _InfoTile(etiqueta: 'Número de Teléfono', valor: p.telefono),
            const SizedBox(height: 30),
            const _TituloSeccion(titulo: 'Cuenta'),
            const SizedBox(height: 16),
            _BotonAccionCuenta(texto: 'Cerrar Sesión', icono: Icons.logout, onTap: _cerrarSesion),
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
        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
          Text(etiqueta, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
            child: Text(valor, style: const TextStyle(color: Colors.white, fontSize: 16)),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: colorTexto != Colors.white ? Border.all(color: cardColor) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, color: colorTexto, size: 22),
              const SizedBox(width: 8),
              Text(texto, style: TextStyle(color: colorTexto, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
      );
}
