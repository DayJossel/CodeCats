// lib/main.dart
import 'package:flutter/material.dart';

import 'backend/core/app_boot.dart';
import 'backend/dominio/auth.dart'; // para AuthUC.tieneSesion()

import 'screens/login.dart';
import 'screens/profile.dart';
import 'screens/vista_alerta.dart';
import 'screens/vista_contactos.dart';
import 'screens/vista_espacios.dart';
import 'screens/vista_calendario.dart';
import 'screens/vista_timer.dart';

// Colores principales de la aplicación
const Color primaryColor = Color(0xFFFFC700);     // Amarillo/Dorado
const Color accentColor = Color(0xFFFE526E);      // Rojo/Rosa SOS
const Color backgroundColor = Color(0xFF121212);  // Fondo oscuro
const Color cardColor = Color(0xFF1E1E1E);        // Color de tarjetas

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBoot.inicializar();
  runApp(const AppChita());
}

class AppChita extends StatelessWidget {
  const AppChita({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CHITA – Seguridad para corredores',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: backgroundColor,
        primaryColor: primaryColor,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: cardColor,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.grey),
        ),
      ),
      home: const PuertaAutenticacion(),
    );
  }
}

class PuertaAutenticacion extends StatefulWidget {
  const PuertaAutenticacion({super.key});

  @override
  State<PuertaAutenticacion> createState() => _EstadoPuertaAutenticacion();
}

class _EstadoPuertaAutenticacion extends State<PuertaAutenticacion> {
  Future<bool> _estaAutenticado() => AuthUC.tieneSesion();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _estaAutenticado(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),
          );
        }
        // Si hay dato, decide a qué pantalla ir
        final autenticado = snap.data ?? false;
        return autenticado
            ? const PantallaPrincipal()
            : const AuthScreen();
      },
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _EstadoPantallaPrincipal();
}

class _EstadoPantallaPrincipal extends State<PantallaPrincipal> {
  int _indiceSeleccionado = 0;

  static final List<Widget> _opcionesWidgets = <Widget>[
    const VistaAlerta(),
    const VistaEspacios(),
    const VistaContactos(),
    const VistaCalendario(),
    const VistaTimer(),
    const ProfileScreen(),
  ];

  void _alTocarItem(int indice) {
    setState(() => _indiceSeleccionado = indice);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _opcionesWidgets.elementAt(_indiceSeleccionado),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.route),
            label: 'Espacios',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'Contactos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            label: 'Calendario',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.timer_outlined),
            label: 'Timer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
        currentIndex: _indiceSeleccionado,
        onTap: _alTocarItem,
      ),
    );
  }
}
