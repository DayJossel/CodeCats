// lib/screens/vista_timer.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui'; // Para FontFeature

import '../main.dart'; // Importamos los colores principales (primaryColor, backgroundColor, cardColor, accentColor)

class VistaTimer extends StatefulWidget {
  const VistaTimer({super.key});

  @override
  State<VistaTimer> createState() => _EstadoVistaTimer();
}

class _EstadoVistaTimer extends State<VistaTimer> {
  late Stopwatch _stopwatch;
  late Timer _timer;
  String _tiempoTranscurrido = '00:00:00';
  bool _estaCorriendo = false;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    // Inicializar un timer que no esté activo hasta que se presione iniciar.
    // Usamos una duración grande para que no se ejecute inmediatamente.
    _timer = Timer(const Duration(milliseconds: 100), () {});
  }

  void _iniciarDetener() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _timer.cancel();
      setState(() {
        _estaCorriendo = false;
      });
    } else {
      _stopwatch.start();
      // Usar Timer.periodic para actualizar el UI cada segundo
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_stopwatch.isRunning) {
          setState(() {
            _actualizarTiempo();
          });
        }
      });
      setState(() {
        _estaCorriendo = true;
      });
    }
  }

  void _reiniciar() {
    _stopwatch.reset();
    if (_timer.isActive) {
      _timer.cancel();
    }
    setState(() {
      _tiempoTranscurrido = '00:00:00';
      _estaCorriendo = false;
    });
  }

  void _actualizarTiempo() {
    final milliseconds = _stopwatch.elapsedMilliseconds;
    final seconds = (milliseconds / 1000).truncate();
    final minutes = (seconds / 60).truncate();
    final hours = (minutes / 60).truncate();

    final remainingSeconds = seconds % 60;
    final remainingMinutes = minutes % 60;

    _tiempoTranscurrido =
        '${_dosDigitos(hours)}:${_dosDigitos(remainingMinutes)}:${_dosDigitos(remainingSeconds)}';
  }

  String _dosDigitos(int n) => n.toString().padLeft(2, '0');

  @override
  void dispose() {
    if (_timer.isActive) {
      _timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Acceder a los colores definidos en main.dart
    final Color cardColor = Theme.of(context).bottomNavigationBarTheme.backgroundColor ?? const Color(0xFF1E1E1E);
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor = const Color(0xFFFE526E); // SOS Color from main.dart
    final Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Temporizador de Carrera'),
        backgroundColor: backgroundColor,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Display del Tiempo
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Text(
                  _tiempoTranscurrido,
                  style: TextStyle(
                    fontSize: 68,
                    fontWeight: FontWeight.w100,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Botones de control
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Botón de Reiniciar
                  ElevatedButton(
                    onPressed: _reiniciar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.2),
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Reiniciar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 20),

                  // Botón de Iniciar/Detener
                  ElevatedButton(
                    onPressed: _iniciarDetener,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _estaCorriendo ? accentColor : primaryColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _estaCorriendo ? 'Detener' : (_stopwatch.elapsed.inSeconds > 0 ? 'Continuar' : 'Iniciar'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}