import 'package:flutter/material.dart';
import '../main.dart'; // Para los colores

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

// --- VISTA DE INICIO DE SESIÓN ---
class _LoginView extends StatelessWidget {
  final VoidCallback onToggle;
  const _LoginView({required this.onToggle});

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
        _buildTextField(label: 'Correo electrónico'),
        const SizedBox(height: 16),
        _buildTextField(label: 'Contraseña', obscureText: true),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // Lógica de inicio de sesión
               Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainScreen()),
              );
            },
            child: const Text('Iniciar Sesión'),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('¿No tienes cuenta? '),
            GestureDetector(
              onTap: onToggle,
              child: const Text(
                'Regístrate',
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --- VISTA DE CREAR CUENTA ---
class _SignUpView extends StatelessWidget {
  final VoidCallback onToggle;
  const _SignUpView({required this.onToggle});

  @override
  Widget build(BuildContext context) {
    // Simula un mensaje de error para mostrar el diseño
    String? errorMessage; // Cambia a un texto para ver el error
    
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
        if(errorMessage != null) ...[
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12)
                ),
                child: Text(errorMessage, style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 20),
        ],
        Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: cardColor,
                child: Icon(Icons.person, size: 50, color: Colors.grey),
              ),
              CircleAvatar(
                radius: 15,
                backgroundColor: Colors.grey[800],
                child: const Icon(Icons.camera_alt, size: 15, color: primaryColor),
              )
            ],
          ),
        ),
        const Center(child: Text('Agregar foto (opcional)', style: TextStyle(color: Colors.grey))),
        const SizedBox(height: 30),
        _buildTextField(label: 'Nombre completo'),
        const SizedBox(height: 16),
        _buildTextField(label: 'Correo electrónico'),
        const SizedBox(height: 16),
        _buildTextField(label: 'Contraseña', obscureText: true),
        const SizedBox(height: 16),
        _buildTextField(label: 'Número de teléfono'),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // Lógica para crear cuenta
            },
            child: const Text('Crear Cuenta'),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('¿Ya tienes cuenta? '),
            GestureDetector(
              onTap: onToggle,
              child: const Text(
                'Inicia Sesión',
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// Helper reutilizable para los campos de texto
Widget _buildTextField({required String label, bool obscureText = false}) {
  return TextField(
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