import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Para colores y MainScreen

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;

  void _toggleAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: _isLogin
              ? _LoginView(onToggle: _toggleAuthMode)
              : _SignUpView(onToggle: _toggleAuthMode),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// VISTA DE INICIO DE SESIÓN
// ------------------------------------------------------------
class _LoginView extends StatefulWidget {
  final VoidCallback onToggle;
  const _LoginView({required this.onToggle});

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final correoController = TextEditingController();
  final contraseniaController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    final correo = correoController.text.trim();
    final contrasenia = contraseniaController.text.trim();

    if (correo.isEmpty || contrasenia.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena todos los campos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://157.137.187.110:8000/corredores/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'correo': correo, 'contrasenia': contrasenia}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['ok'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('corredor_id', data['corredor_id']);
          await prefs.setString('nombre', data['nombre']);
          await prefs.setString('correo', correo);
          await prefs.setString('contrasenia', contrasenia);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bienvenido ${data['nombre']}')),
          );

          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Credenciales incorrectas')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${response.statusCode}: ${response.body}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.1),
        const Text(
          'Bienvenido',
          style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Inicia sesión para continuar',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.1),
        _buildTextField(
          label: 'Correo electrónico',
          controller: correoController,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Contraseña',
          controller: contraseniaController,
          obscureText: true,
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _login,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Iniciar Sesión'),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('¿No tienes cuenta? '),
            GestureDetector(
              onTap: widget.onToggle,
              child: const Text(
                'Regístrate',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// VISTA DE CREAR CUENTA
// ------------------------------------------------------------
class _SignUpView extends StatefulWidget {
  final VoidCallback onToggle;
  const _SignUpView({required this.onToggle});

  @override
  State<_SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<_SignUpView> {
  final nombreController = TextEditingController();
  final correoController = TextEditingController();
  final contraseniaController = TextEditingController();
  final telefonoController = TextEditingController();
  bool _isLoading = false;

  Future<void> _register() async {
    final nombre = nombreController.text.trim();
    final correo = correoController.text.trim();
    final contrasenia = contraseniaController.text.trim();
    final telefono = telefonoController.text.trim();

    if (nombre.isEmpty ||
        correo.isEmpty ||
        contrasenia.isEmpty ||
        telefono.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena todos los campos')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://157.137.187.110:8000/corredores'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre,
          'correo': correo,
          'contrasenia': contrasenia,
          'telefono': telefono,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cuenta creada: ${data['nombre']}')),
        );
        widget.onToggle();
      } else {
        final error = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${error['detail'] ?? 'No se pudo registrar'}',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40),
        const Text(
          'Crear Cuenta',
          style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Únete a CHITA para correr seguro',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
        const SizedBox(height: 30),
        _buildTextField(label: 'Nombre completo', controller: nombreController),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Correo electrónico',
          controller: correoController,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Contraseña',
          controller: contraseniaController,
          obscureText: true,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Número de teléfono',
          controller: telefonoController,
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _register,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Crear Cuenta'),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('¿Ya tienes cuenta? '),
            GestureDetector(
              onTap: widget.onToggle,
              child: const Text(
                'Inicia Sesión',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// HELPER REUTILIZABLE
// ------------------------------------------------------------
Widget _buildTextField({
  required String label,
  required TextEditingController controller,
  bool obscureText = false,
}) {
  return TextField(
    controller: controller,
    obscureText: obscureText,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor),
      ),
    ),
  );
}
