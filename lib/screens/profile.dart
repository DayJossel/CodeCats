import 'dart:convert';
import 'package:chita_app/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../core/session_repository.dart';

class PantallaPerfil extends StatefulWidget {
  const PantallaPerfil({super.key});

  @override
  State<PantallaPerfil> createState() => _EstadoPantallaPerfil();
}

// Compatibilidad
class ProfileScreen extends PantallaPerfil {
  const ProfileScreen({super.key});
}

class _EstadoPantallaPerfil extends State<PantallaPerfil> {
  String nombre = '';
  String correo = '';
  String telefono = '';
  int corredorId = 0;
  String contrasenia = '';
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    corredorId = prefs.getInt('corredor_id') ?? 0;
    contrasenia = prefs.getString('contrasenia') ?? '';

    if (corredorId != 0 && contrasenia.isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse('http://157.137.187.110:8000/corredores/$corredorId'),
          headers: {'X-Corredor-Id': '$corredorId', 'X-Contrasenia': contrasenia},
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            nombre = (data['nombre'] as String?) ?? '';
            correo = (data['correo'] as String?) ?? '';
            telefono = (data['telefono'] as String?) ?? '';
            _cargando = false;
          });
        } else {
          setState(() => _cargando = false);
        }
      } catch (_) {
        setState(() => _cargando = false);
      }
    } else {
      setState(() => _cargando = false);
    }
  }

  Future<void> _cerrarSesion() async {
    await RepositorioSesion.limpiar(); // alias al SessionRepository.clear()
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  Future<void> _eliminarCuenta() async {
    try {
      final response = await http.delete(
        Uri.parse('http://157.137.187.110:8000/corredores/$corredorId'),
        headers: {'X-Corredor-Id': '$corredorId', 'X-Contrasenia': contrasenia},
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Cuenta eliminada exitosamente')));
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar la cuenta: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    }
  }

  void _mostrarConfirmacionEliminacion() {
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

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          children: [
            Center(
              child: Text(
                correo,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),
            const _TituloSeccion(titulo: 'Información Personal'),
            const SizedBox(height: 16),
            _InfoTile(etiqueta: 'Nombre Completo', valor: nombre),
            const SizedBox(height: 16),
            _InfoTile(etiqueta: 'Email', valor: correo),
            const SizedBox(height: 16),
            _InfoTile(etiqueta: 'Número de Teléfono', valor: telefono),
            const SizedBox(height: 30),
            const _TituloSeccion(titulo: 'Cuenta'),
            const SizedBox(height: 16),
            _BotonAccionCuenta(texto: 'Cerrar Sesión', icono: Icons.logout, onTap: _cerrarSesion),
            const SizedBox(height: 16),
            _BotonAccionCuenta(
              texto: 'Eliminar Cuenta',
              icono: Icons.delete_outline,
              colorTexto: accentColor,
              onTap: _mostrarConfirmacionEliminacion,
            ),
          ],
        ),
      ),
    );
  }
}

// Reutilizables
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
