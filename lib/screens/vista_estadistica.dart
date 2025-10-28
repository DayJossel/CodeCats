import 'package:flutter/material.dart';
import '../main.dart'; // Importa para usar los colores globales

class VistaEstadistica extends StatelessWidget {
  const VistaEstadistica({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Objetivo Mensual'),
        elevation: 0,
        backgroundColor: backgroundColor,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart_outlined, size: 80, color: Colors.grey[600]),
              const SizedBox(height: 20),
              const Text(
                'Estadísticas',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Próximamente podrás consultar aquí tus estadísticas, como distancia, ritmo y frecuencia de carreras.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}