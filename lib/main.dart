// lib/main.dart
import 'package:flutter/material.dart';

import 'core/session_repository.dart';
import 'core/notification_service.dart';

import 'screens/login.dart';
import 'screens/profile.dart';
import 'screens/vista_alerta.dart';
import 'screens/vista_contactos.dart';
import 'screens/vista_espacios.dart';
import 'screens/vista_calendario.dart';

// Colores principales de la aplicación
const Color primaryColor = Color(0xFFFFC700);     // Amarillo/Dorado
const Color accentColor = Color(0xFFFE526E);      // Rojo/Rosa SOS
const Color backgroundColor = Color(0xFF121212);  // Fondo oscuro
const Color cardColor = Color(0xFF1E1E1E);        // Color de tarjetas

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa notificaciones y solicita permisos
  await ServicioNotificaciones.instancia.inicializar();
  await ServicioNotificaciones.instancia.solicitarPermisoNotificaciones();

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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          headlineSmall: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
  State<PuertaAutenticacion> createState() => EstadoPuertaAutenticacion();
}

class EstadoPuertaAutenticacion extends State<PuertaAutenticacion> {
  Future<bool> _estaAutenticado() async {
    final id = await RepositorioSesion.obtenerCorredorId();
    final pwd = await RepositorioSesion.obtenerContrasenia();
    return id != null && (pwd != null && pwd.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _estaAutenticado(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snap.data! ? const PantallaPrincipal() : const AuthScreen();
      },
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => EstadoPantallaPrincipal();
}

class EstadoPantallaPrincipal extends State<PantallaPrincipal> {
  int _indiceSeleccionado = 0;

  static final List<Widget> _opcionesWidgets = <Widget>[
    const VistaAlerta(),
    const VistaEspacios(),
    const VistaContactos(),
    const VistaCalendario(),
    const ProfileScreen(), // ← cuando renombremos profile.dart, cambiamos aquí también
  ];

  void _alTocarItem(int indice) {
    // 🔒 Deshabilitar temporalmente la pestaña de Perfil (índice 4)
    if (indice == 4) {
      return;
    }
    setState(() => _indiceSeleccionado = indice);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: _opcionesWidgets.elementAt(_indiceSeleccionado)),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Espacios'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Contactos'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today_outlined), label: 'Calendario'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Perfil'),
        ],
        currentIndex: _indiceSeleccionado,
        onTap: _alTocarItem,
      ),
    );
  }
}
