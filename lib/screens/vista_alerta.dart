import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import 'vista_historial.dart';
import 'vista_ubicacion.dart';
import 'vista_alerta_emergencia.dart';

class VistaAlerta extends StatefulWidget {
  const VistaAlerta({super.key});

  @override
  State<VistaAlerta> createState() => EstadoVistaAlerta();
}

class EstadoVistaAlerta extends State<VistaAlerta> {
  bool _enviando = false;
  String? _mensajeEstado;
  bool _contando = false;
  int _valorCuenta = 3;
  Timer? _timer;
  double _animOnda = 0.0;
  Timer? _timerOnda;

  void _iniciarCuentaAtras() {
    setState(() {
      _contando = true;
      _valorCuenta = 3;
      _animOnda = 0.0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_valorCuenta > 1) {
          _valorCuenta--;
        } else {
          _timer?.cancel();
          _timerOnda?.cancel();
          _contando = false;
          _mostrarDialogoConfirmacionSos(context);
        }
      });
    });

    _timerOnda = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      setState(() {
        _animOnda = _animOnda == 0.0 ? 1.0 : 0.0;
      });
    });
  }

  Future<void> _enviarEmergencia() async {
    if (_enviando) return;
    setState(() { _enviando = true; _mensajeEstado = null; });

    try {
      final res = await CasoUsoAlertaEmergencia.activarAlertaEmergencia();
      final okTotal = res.fallidos.isEmpty;
      final base = okTotal
          ? 'Alerta enviada a todos los contactos.'
          : 'Alerta enviada con fallos a ${res.fallidos.length} contacto(s).';
      final hid = res.historialId != null ? ' (Historial #${res.historialId})' : '';
      if (!mounted) return;
      setState(() => _mensajeEstado = base + hid);

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
    } catch (_) {
      if (!mounted) return;
      setState(() => _mensajeEstado = '❌ No se pudo enviar la alerta.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Falló el envío de la alerta. Intenta de nuevo.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _cancelarCuentaAtras() {
    _timer?.cancel();
    _timerOnda?.cancel();
    setState(() {
      _contando = false;
      _valorCuenta = 3;
      _animOnda = 0.0;
    });
  }

  void _mostrarDialogoConfirmacionSos(BuildContext context) {
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
                    await _enviarEmergencia();
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
    _timerOnda?.cancel();
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
                    if (_contando)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        width: 180 + (_animOnda * 40),
                        height: 180 + (_animOnda * 40),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(
                            0.3 - (_animOnda * 0.2),
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    GestureDetector(
                      onTapDown: (_) => _iniciarCuentaAtras(),
                      onTapUp: (_) => _cancelarCuentaAtras(),
                      onTapCancel: _cancelarCuentaAtras,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: _contando ? Colors.red : accentColor,
                          shape: BoxShape.circle,
                          boxShadow: _contando
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
                          child: _contando
                              ? Text(
                                  '$_valorCuenta',
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
                  _contando
                      ? 'Mantén presionado... $_valorCuenta'
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
