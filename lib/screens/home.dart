import 'dart:async';

import 'package:chita_app/screens/share_location.dart';
import 'package:flutter/material.dart';
import '../main.dart'; // Importamos para usar los colores

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isCountingDown = false;
  int _countdownValue = 3;
  late Timer _timer;
  double _waveAnimation = 0.0;
  late Timer _waveTimer;

  void _startCountdown() {
    setState(() {
      _isCountingDown = true;
      _countdownValue = 3;
      _waveAnimation = 0.0;
    });

    // Timer para la cuenta regresiva
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdownValue > 1) {
          _countdownValue--;
        } else {
          _timer.cancel();
          _waveTimer.cancel();
          _isCountingDown = false;
          _showSosConfirmationDialog(context);
        }
      });
    });

    // Timer para la animación de ondas
    _waveTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      setState(() {
        _waveAnimation = _waveAnimation == 0.0 ? 1.0 : 0.0;
      });
    });
  }

  void _cancelCountdown() {
    if (_timer.isActive) {
      _timer.cancel();
    }
    if (_waveTimer.isActive) {
      _waveTimer.cancel();
    }
    setState(() {
      _isCountingDown = false;
      _countdownValue = 3;
      _waveAnimation = 0.0;
    });
  }

  void _showSosConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            '¿Enviar alerta de Emergencia?',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Esto notificará a todos tus contactos de emergencia con tu ubicación actual.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancelar'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Enviar Alerta'),
                  onPressed: () {
                    // Aquí iría la lógica para enviar la alerta
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    if (_timer.isActive) {
      _timer.cancel();
    }
    if (_waveTimer.isActive) {
      _waveTimer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Hola Corredor',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                'Mantente seguro en tu próxima carrera',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[400],
                    ),
              ),
              const Spacer(),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Efecto de ondas
                    if (_isCountingDown)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        width: 180 + (_waveAnimation * 40),
                        height: 180 + (_waveAnimation * 40),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.3 - (_waveAnimation * 0.2)),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.red.withOpacity(0.5 - (_waveAnimation * 0.3)),
                            width: 2,
                          ),
                        ),
                      ),
                    if (_isCountingDown)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        width: 180 + (_waveAnimation * 20),
                        height: 180 + (_waveAnimation * 20),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2 - (_waveAnimation * 0.15)),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.red.withOpacity(0.4 - (_waveAnimation * 0.25)),
                            width: 1.5,
                          ),
                        ),
                      ),
                    // Botón principal
                    GestureDetector(
                      onTapDown: (_) => _startCountdown(),
                      onTapUp: (_) => _cancelCountdown(),
                      onTapCancel: _cancelCountdown,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: _isCountingDown ? Colors.red : accentColor,
                          shape: BoxShape.circle,
                          boxShadow: _isCountingDown
                              ? [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.6),
                                    blurRadius: 15,
                                    spreadRadius: 5,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: _isCountingDown
                              ? Text(
                                  '$_countdownValue',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 64,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : const Text(
                                  'SOS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              Center(
                child: Text(
                  _isCountingDown 
                    ? 'Mantén presionado... $_countdownValue' 
                    : 'Mantén presionado 3 segundos',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              const Spacer(),
              // --- CARD HORIZONTAL COMPARTIR UBICACIÓN ---
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ShareLocationScreen()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 80, // Altura ajustada para formato horizontal
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.share_location, color: primaryColor, size: 30),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Compartir Ubicación',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Comparte tu ubicación',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 15),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primaryColor, size: 30),
            const SizedBox(height: 15),
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            if (subtitle.isNotEmpty)
              Text(subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}