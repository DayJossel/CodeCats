import 'dart:async';
import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import '../main.dart';
import 'vista_ubicacion.dart';

class VistaAlerta extends StatefulWidget {
  const VistaAlerta({super.key});

  @override
  State<VistaAlerta> createState() => _VistaAlertaState();
}

class _VistaAlertaState extends State<VistaAlerta> {
  bool _isCountingDown = false;
  int _countdownValue = 3;
  late Timer _timer;
  double _waveAnimation = 0.0;
  late Timer _waveTimer;
  final Telephony telephony = Telephony.instance;

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
          _timer.cancel();
          _waveTimer.cancel();
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

  void _cancelCountdown() {
    if (_timer.isActive) _timer.cancel();
    if (_waveTimer.isActive) _waveTimer.cancel();
    setState(() {
      _isCountingDown = false;
      _countdownValue = 3;
      _waveAnimation = 0.0;
    });
  }

  // ✅ Envío real del SMS
  Future<bool> _enviarAlerta() async {
    try {
      // Datos del corredor (luego puedes traerlos desde tu backend o base local)
      const String nombre = "Jorge Ruvalcaba";
      const String id = "CHTA-023";
      const double lat = 20.6751;
      const double lng = -103.3473;

      final String mensaje =
          '''
🚨 ALERTA CHITA 🚨
Soy $nombre (ID: $id).
Necesito ayuda urgente.
Última ubicación: https://maps.google.com/?q=$lat,$lng
''';

      // Contactos de confianza (números reales con prefijo internacional)
      final List<String> contactos = ["+5213312345678", "+5213333345678"];

      bool permisos = await telephony.requestSmsPermissions ?? false;

      if (!permisos) return false;

      for (String numero in contactos) {
        await telephony.sendSms(to: numero, message: mensaje);
      }

      return true;
    } catch (e) {
      print("Error al enviar SMS: $e");
      return false;
    }
  }

  // ✅ Diálogo de confirmación con resultado real
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
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Enviar Alerta'),
                  onPressed: () async {
                    Navigator.of(context).pop(); // Cierra el diálogo

                    bool success = await _enviarAlerta();

                    if (!mounted) return;

                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '🚨 Alerta enviada con éxito',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '❌ Falló el envío de la alerta. Intenta de nuevo.',
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
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
    if (_timer.isActive) _timer.cancel();
    if (_waveTimer.isActive) _waveTimer.cancel();
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
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
