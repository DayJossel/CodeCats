import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../backend/core/session_repository.dart';
import '../backend/data/api_service.dart';
import '../main.dart'; // Colores y MainScreen

class PantallaAutenticacion extends StatefulWidget {
  const PantallaAutenticacion({super.key});

  @override
  State<PantallaAutenticacion> createState() => EstadoPantallaAutenticacion();
}

// Compatibilidad con código que referencie AuthScreen
class AuthScreen extends PantallaAutenticacion {
  const AuthScreen({super.key});
}

class EstadoPantallaAutenticacion extends State<PantallaAutenticacion> {
  bool _esLogin = true;

  void _alternarModo() {
    setState(() {
      _esLogin = !_esLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: _esLogin
              ? VistaLogin(onToggle: _alternarModo)
              : VistaRegistro(onToggle: _alternarModo),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// VISTA DE INICIO DE SESIÓN
// ------------------------------------------------------------
class VistaLogin extends StatefulWidget {
  final VoidCallback onToggle;
  const VistaLogin({required this.onToggle});

  @override
  State<VistaLogin> createState() => EstadoVistaLogin();
}

class EstadoVistaLogin extends State<VistaLogin> {
  final correoController = TextEditingController();
  final contraseniaController = TextEditingController();
  bool _cargando = false;

  @override
  void dispose() {
    correoController.dispose();
    contraseniaController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    final correo = correoController.text.trim();
    final contrasenia = contraseniaController.text.trim();

    if (correo.isEmpty || contrasenia.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena todos los campos')),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      // Preferimos el servicio centralizado (maneja errores y formato)
      final data = await ServicioApi.iniciarSesion(
        correo: correo,
        contrasenia: contrasenia,
      );

      // Acepta tanto respuestas con {ok:true,...} como sin 'ok'
      final corredorId = (data['corredor_id'] as num?)?.toInt() ??
          (data['id'] as num?)?.toInt();
      final nombre = (data['nombre'] as String?) ?? '';
      final ok = (data['ok'] == true) || (corredorId != null);

      if (ok && corredorId != null) {
        await RepositorioSesion.guardarLogin(
          corredorId: corredorId,
          contrasenia: contrasenia,
          nombre: nombre,
          correo: correo,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bienvenido $nombre')),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PantallaPrincipal()),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenciales incorrectas')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    } finally {
      if (mounted) setState(() => _cargando = false);
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
        _construirCampoTexto(
          label: 'Correo electrónico',
          controller: correoController,
        ),
        const SizedBox(height: 16),
        _construirCampoTexto(
          label: 'Contraseña',
          controller: contraseniaController,
          obscureText: true,
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _cargando ? null : _iniciarSesion,
            child: _cargando
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
class VistaRegistro extends StatefulWidget {
  final VoidCallback onToggle;
  const VistaRegistro({required this.onToggle});

  @override
  State<VistaRegistro> createState() => EstadoVistaRegistro();
}

class EstadoVistaRegistro extends State<VistaRegistro> {
  final nombreController = TextEditingController();
  final correoController = TextEditingController();
  final contraseniaController = TextEditingController();
  final telefonoController = TextEditingController();
  bool _cargando = false;

  @override
  void dispose() {
    nombreController.dispose();
    correoController.dispose();
    contraseniaController.dispose();
    telefonoController.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    final nombre = nombreController.text.trim();
    final correo = correoController.text.trim();
    final contrasenia = contraseniaController.text.trim();
    final telefono = telefonoController.text.trim();

    if (nombre.isEmpty ||
        correo.isEmpty ||
        contrasenia.isEmpty ||
        telefono.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena todos los campos')),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      // Registro directo (si quieres lo movemos luego a ServicioApi)
      final resp = await http.post(
        Uri.parse('http://157.137.187.110:8000/corredores'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre,
          'correo': correo,
          'contrasenia': contrasenia,
          'telefono': telefono,
        }),
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cuenta creada: ${data['nombre']}')),
        );
        widget.onToggle(); // vuelve a la vista de login
      } else {
        final error = jsonDecode(resp.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${error['detail'] ?? 'No se pudo registrar'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error de conexión: $e')));
    } finally {
      if (mounted) setState(() => _cargando = false);
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
        _construirCampoTexto(label: 'Nombre completo', controller: nombreController),
        const SizedBox(height: 16),
        _construirCampoTexto(
          label: 'Correo electrónico',
          controller: correoController,
        ),
        const SizedBox(height: 16),
        _construirCampoTexto(
          label: 'Contraseña',
          controller: contraseniaController,
          obscureText: true,
        ),
        const SizedBox(height: 16),
        _construirCampoTexto(
          label: 'Número de teléfono',
          controller: telefonoController,
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _cargando ? null : _registrar,
            child: _cargando
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
Widget _construirCampoTexto({
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
