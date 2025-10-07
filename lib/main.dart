import 'package:chita_app/screens/alert.dart';
import 'package:chita_app/screens/contacts.dart';
import 'package:chita_app/screens/home.dart';
import 'package:chita_app/screens/profile.dart';
import 'package:chita_app/screens/route.dart';
import 'package:flutter/material.dart';


// Colores principales de la aplicación para fácil acceso
const Color primaryColor = Color(0xFFFFC700); // Amarillo/Dorado
const Color accentColor = Color(0xFFFE526E);  // Rojo/Rosa SOS
const Color backgroundColor = Color(0xFF121212); // Fondo oscuro
const Color cardColor = Color(0xFF1E1E1E);      // Color de tarjetas

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
        // Definimos un tema para los botones elevados
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black, backgroundColor: primaryColor, // texto negro, fondo amarillo
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        // Tema para la barra de navegación inferior
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
      home: const MainScreen(),
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
    const HomeScreen(),
    const RoutesScreen(),
    const ContactsScreen(),
    const AlertsScreen(),
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
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.route),
            label: 'Espacios para correr',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            label: 'Contactos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            label: 'Alertas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}