import 'dart:convert';
import 'package:chita_app/screens/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Colores y MainScreen
import '../core/session_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String nombre = '';
  String correo = '';
  String telefono = '';
  int corredorId = 0;
  String contrasenia = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    corredorId = prefs.getInt('corredor_id') ?? 0;
    contrasenia = prefs.getString('contrasenia') ?? '';

    if (corredorId != 0 && contrasenia.isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse('http://157.137.187.110:8000/corredores/$corredorId'),
          headers: {
            'X-Corredor-Id': corredorId.toString(),
            'X-Contrasenia': contrasenia,
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            nombre = data['nombre'] ?? '';
            correo = data['correo'] ?? '';
            telefono = data['telefono'] ?? '';
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } catch (e) {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    // borra todas las claves que usa la sesión: corredor_id, correo, nombre, contrasenia
    await SessionRepository.clear();

    if (!mounted) return;

    // Limpia el stack y manda al login
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }


  Future<void> _deleteAccount() async {
    try {
      final response = await http.delete(
        Uri.parse('http://157.137.187.110:8000/corredores/$corredorId'),
        headers: {
          'X-Corredor-Id': corredorId.toString(),
          'X-Contrasenia': contrasenia,
        },
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cuenta eliminada exitosamente')),
          );

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar la cuenta: ${response.body}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    }
  }

  void _showDeleteConfirmation() {
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
                  _deleteAccount();
                },
                child: const Text(
                  'Eliminar Cuenta',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const _SectionTitle(title: 'Información Personal'),
            const SizedBox(height: 16),
            _InfoTile(label: 'Nombre Completo', value: nombre),
            const SizedBox(height: 16),
            _InfoTile(label: 'Email', value: correo),
            const SizedBox(height: 16),
            _InfoTile(label: 'Número de Teléfono', value: telefono),
            const SizedBox(height: 30),
            const _SectionTitle(title: 'Cuenta'),
            const SizedBox(height: 16),
            _AccountActionButton(
              text: 'Cerrar Sesión',
              icon: Icons.logout,
              onTap: _logout,
            ),
            const SizedBox(height: 16),
            _AccountActionButton(
              text: 'Eliminar Cuenta',
              icon: Icons.delete_outline,
              textColor: accentColor,
              onTap: _showDeleteConfirmation,
            ),
          ],
        ),
      ),
    );
  }
}

// Reutilizables
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  );
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  const _InfoTile({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    ],
  );
}

class _AccountActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final Color textColor;
  const _AccountActionButton({
    required this.text,
    required this.icon,
    required this.onTap,
    this.textColor = Colors.white,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: textColor != Colors.white ? Border.all(color: cardColor) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 22),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    ),
  );
}
