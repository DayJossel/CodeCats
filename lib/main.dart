import 'package:flutter/material.dart';

import 'core/session_repository.dart';

import 'screens/login.dart';          // AuthScreen
import 'screens/profile.dart';        // ProfileScreen (tab)
import 'screens/vista_alerta.dart';
import 'screens/vista_contactos.dart';
import 'screens/vista_historial.dart';
import 'screens/vista_espacios.dart';

// Colores principales de la aplicación para fácil acceso
const Color primaryColor = Color(0xFFFFC700); // Amarillo/Dorado
const Color accentColor = Color(0xFFFE526E);  // Rojo/Rosa SOS
const Color backgroundColor = Color(0xFF121212); // Fondo oscuro
const Color cardColor = Color(0xFF1E1E1E);    // Color de tarjetas

void main() {
  runApp(const RunnerApp());
}

class RunnerApp extends StatelessWidget {
  const RunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Runner Safety App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: backgroundColor,
        primaryColor: primaryColor,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: primaryColor, // texto negro, fondo amarillo
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
      home: const _AuthGate(), // 👈 IMPORTANTE: ya no AuthScreen directo
    );
  }
}

/// Gate que decide si hay sesión persistida.
/// Si hay (id y contraseña), entra directo a MainScreen; si no, a AuthScreen.
class _AuthGate extends StatefulWidget {
  const _AuthGate({super.key});
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  Future<bool> _isLoggedIn() async {
    final id = await SessionRepository.corredorId();
    final pwd = await SessionRepository.contrasenia();
    return id != null && (pwd != null && pwd.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedIn(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snap.data! ? const MainScreen() : const AuthScreen();
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const VistaAlerta(),
    const VistaEspacios(),
    const VistaContactos(),
    const VistaHistorial(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Espacios para correr'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Contactos'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none), label: 'Alertas'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
