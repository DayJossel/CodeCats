import 'package:flutter/material.dart';
import '../main.dart'; // Importamos para usar los colores

class MapDetailScreen extends StatelessWidget {
  final String routeTitle;
  final String routeCoordinates;
  final String mapImagePath;

  const MapDetailScreen({
    super.key,
    required this.routeTitle,
    required this.routeCoordinates,
    required this.mapImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
     
        elevation: 0, 
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          routeTitle,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // FONDO CON IMAGEN DEL MAPA
          Positioned.fill(
            child: Image.asset(
              mapImagePath,
              fit: BoxFit.cover,
            ),
          ),
          // PANEL DE INFORMACIÓN INFERIOR
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration:  BoxDecoration(
                color: backgroundColor,
                // Si quieres un borde superior, descomenta la siguiente línea
                 border: Border(top: BorderSide(color: Colors.grey[800]!))
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    routeTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    routeCoordinates,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}