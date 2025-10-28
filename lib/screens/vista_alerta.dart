import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import 'vista_historial.dart'; // Importamos la vista de historial
import 'vista_ubicacion.dart';
import '../usecases/emergency_alert_uc.dart';

class VistaAlerta extends StatefulWidget {
  const VistaAlerta({super.key});

  @override
  State<VistaAlerta> createState() => _VistaAlertaState();
}

class _VistaAlertaState extends State<VistaAlerta> {
  bool _sending = false;
  String? _statusMsg;
  bool _isCountingDown = false;
  int _countdownValue = 3;
  Timer? _timer;
  double _waveAnimation = 0.0;
  Timer? _waveTimer;

  void _startCountdown() {
    setState(() {
      _isCountingDown = true;
      _countdownValue = 3;
      _waveAnimation = 0.0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdownValue > 1) {
          _countdownValue--;
        } else {
          _timer?.cancel();
          _waveTimer?.cancel();
          _isCountingDown = false;
          _showSosConfirmationDialog(context);
        }
      });
    });

    _waveTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      setState(() {
        _waveAnimation = _waveAnimation == 0.0 ? 1.0 : 0.0;
      });
    });
  }

  Future<void> _sendEmergency() async {
    if (_sending) return;
    setState(() { _sending = true; _statusMsg = null; });

    try {
      final res = await EmergencyAlertUC.trigger();
      final okTotal = res.fallidos.isEmpty;
      final base = okTotal
          ? 'Alerta enviada a todos los contactos.'
          : 'Alerta enviada con fallos a ${res.fallidos.length} contacto(s).';
      final hid = res.historialId != null ? ' (Historial #${res.historialId})' : '';
      if (!mounted) return;
      setState(() => _statusMsg = base + hid);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(okTotal
              ? '🚨 Alerta enviada con éxito'
              : '⚠️ Alerta enviada con algunos fallos'),
          backgroundColor: okTotal ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMsg = '❌ No se pudo enviar la alerta: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Falló el envío de la alerta. Intenta de nuevo.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _cancelCountdown() {
    _timer?.cancel();
    _waveTimer?.cancel();
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            '¿Enviar alerta de Emergencia?',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Esto notificará a tus contactos de emergencia con tu ubicación actual.',
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
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Enviar Alerta'),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _sendEmergency();
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
    _timer?.cancel();
    _waveTimer?.cancel();
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
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey[400]),
              ),
              const Spacer(),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isCountingDown)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        width: 180 + (_waveAnimation * 40),
                        height: 180 + (_waveAnimation * 40),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(
                            0.3 - (_waveAnimation * 0.2),
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
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
              // Botón de Compartir Ubicación
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VistaUbicacion(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 80,
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
                            const Text(
                              'Compartir Ubicación',
                              style: TextStyle(
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
              // NUEVO BOTÓN: Historial de Alertas
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VistaHistorial(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 80,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: primaryColor, size: 30),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Historial de Alertas',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Consulta tus alertas anteriores',
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
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}