// lib/screens/vista_timer.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart'; // Para el selector de tiempo

import '../main.dart'; // Importamos los colores principales (primaryColor, backgroundColor, cardColor, accentColor)

// Definición de modos del temporizador
enum TimerMode { selection, countdown, stopwatch }

enum TimerState { initial, running, paused, finished }

class VistaTimer extends StatefulWidget {
  const VistaTimer({super.key});

  @override
  State<VistaTimer> createState() => _EstadoVistaTimer();
}

class _EstadoVistaTimer extends State<VistaTimer> {
  // --- Estado Global del Timer ---
  TimerMode _mode = TimerMode.selection;
  TimerState _state = TimerState.initial;

  // --- Propiedades para Cuenta Progresiva (Cronómetro) ---
  final Stopwatch _stopwatch = Stopwatch();
  late Timer _progressiveTimer;
  String _progressiveDisplay = '00:00:000';

  // --- Propiedades para Cuenta Regresiva (Temporizador) ---
  Duration _initialDuration = const Duration(minutes: 5); // Default 5 minutos
  Duration _remainingDuration = Duration.zero;
  late Timer _countdownTimer;
  String _countdownDisplay = '00:05:00'; // Default para 5 minutos

  // Colores (para usarlos sin depender de Theme.of(context) en las utilidades)
  final Color primaryColor = const Color(0xFFFFC700);
  final Color accentColor = const Color(0xFFFE526E); // SOS Color from main.dart
  final Color backgroundColor = const Color(0xFF121212); // Fondo oscuro
  final Color cardColor = const Color(0xFF1E1E1E); // Color de tarjetas

  // --- Constructor y Setup ---

  @override
  void initState() {
    super.initState();
    // Inicialización de timers dummy
    _progressiveTimer = Timer(const Duration(milliseconds: 10), () {});
    _countdownTimer = Timer(const Duration(milliseconds: 10), () {});
    _remainingDuration = _initialDuration;
    _countdownDisplay = _formatDuration(_initialDuration);
  }

  // --- Lógica del Cronómetro (Progresivo) ---

  void _startStopwatch() {
    _stopwatch.start();
    _progressiveTimer = Timer.periodic(const Duration(milliseconds: 10), (
      timer,
    ) {
      if (_stopwatch.isRunning) {
        setState(() {
          _updateProgressiveTime();
        });
      }
    });
  }

  void _pauseStopwatch() {
    _stopwatch.stop();
    _progressiveTimer.cancel();
    setState(() {
      _state = TimerState.paused;
    });
  }

  void _resetStopwatch() {
    _stopwatch.reset();
    _stopwatch.stop();
    if (_progressiveTimer.isActive) _progressiveTimer.cancel();
    setState(() {
      _progressiveDisplay = '00:00:000';
      _state = TimerState.initial;
    });
  }

  void _updateProgressiveTime() {
    final ms = _stopwatch.elapsedMilliseconds;
    _progressiveDisplay = _formatMilliseconds(ms);
  }

  // --- Lógica de Cuenta Regresiva (Temporizador) ---

  // *** FUNCIÓN MODIFICADA ***: Eliminada la llamada a setState para el estado,
  // ya que se maneja en el llamador.
  void _startCountdown() {
    if (_countdownTimer.isActive) _countdownTimer.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingDuration.inSeconds > 0) {
        setState(() {
          _remainingDuration = _remainingDuration - const Duration(seconds: 1);
          _countdownDisplay = _formatDuration(_remainingDuration);
        });
      } else {
        _countdownTimer.cancel();
        _notifyFinished();
      }
    });
  }

  void _pauseCountdown() {
    _countdownTimer.cancel();
    setState(() {
      _state = TimerState.paused;
    });
  }

  void _resetCountdown() {
    if (_countdownTimer.isActive) _countdownTimer.cancel();
    setState(() {
      _remainingDuration = _initialDuration;
      _countdownDisplay = _formatDuration(_initialDuration);
      _state = TimerState.initial;
    });
  }

  void _notifyFinished() {
    setState(() {
      _state = TimerState.finished;
    });
    // Notificación de finalización
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Tiempo terminado! ¡Objetivo completado!'),
        duration: Duration(seconds: 4),
        backgroundColor: Colors.green,
      ),
    );
  }

  // --- Lógica de Interfaz y Navegación ---

  void _selectMode(TimerMode mode) {
    if (mode == TimerMode.countdown) {
      _remainingDuration = _initialDuration;
      _countdownDisplay = _formatDuration(_initialDuration);
    }
    setState(() {
      _mode = mode;
      _state = TimerState.initial;
    });
  }

  void _goBackToSelection() {
    if (_progressiveTimer.isActive) _progressiveTimer.cancel();
    if (_countdownTimer.isActive) _countdownTimer.cancel();
    _stopwatch.stop();
    _stopwatch.reset();

    setState(() {
      _mode = TimerMode.selection;
      _state = TimerState.initial;
      _progressiveDisplay = '00:00:000';
      _remainingDuration = _initialDuration;
      _countdownDisplay = _formatDuration(_initialDuration);
    });
  }

  // --- Lógica de Pausa/Reanudación General ---

  void _togglePlayPause() {
    if (_mode == TimerMode.stopwatch) {
      if (_state == TimerState.running) {
        _pauseStopwatch();
      } else {
        setState(() => _state = TimerState.running);
        _startStopwatch();
      }
    } else if (_mode == TimerMode.countdown) {
      if (_state == TimerState.running) {
        _pauseCountdown();
      } else if (_state == TimerState.initial || _state == TimerState.paused) {
        setState(
          () => _state = TimerState.running,
        ); // Establecer estado a running
        _startCountdown(); // Iniciar/Reanudar
      }
    }
  }

  // --- Métodos de Formato ---

  String _formatMilliseconds(int ms) {
    final minutes = (ms ~/ 60000) % 60;
    final seconds = (ms ~/ 1000) % 60;
    final milliseconds = ms % 1000;

    return '${_dosDigitos(minutes)}:${_dosDigitos(seconds)}:${_tresDigitos(milliseconds)}';
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    // Mostramos HH:MM:SS
    return '${_dosDigitos(hours)}:${_dosDigitos(minutes)}:${_dosDigitos(seconds)}';
  }

  String _dosDigitos(int n) => n.toString().padLeft(2, '0');
  String _tresDigitos(int n) => n.toString().padLeft(3, '0');

  // --- Widgets de Construcción de Vistas ---

  Widget _buildSelectionScreen() {
    // ... (sin cambios)
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Text(
            'Selecciona el Modo de Conteo',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _SelectionButton(
            icon: Icons.timer,
            label: 'Cuenta Regresiva (Temporizador)',
            color: primaryColor,
            onTap: () => _selectMode(TimerMode.countdown),
          ),
          const SizedBox(height: 20),
          _SelectionButton(
            icon: Icons.timer_outlined,
            label: 'Cuenta Progresiva (Cronómetro)',
            color: primaryColor,
            onTap: () => _selectMode(TimerMode.stopwatch),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupScreen() {
    // ...
    // Obtener H:M:S de la duración actual
    int initialHours = _initialDuration.inHours;
    int initialMinutes = _initialDuration.inMinutes.remainder(60);
    int initialSeconds = _initialDuration.inSeconds.remainder(60);

    // Valores temporales para el selector
    int tempHours = initialHours;
    int tempMinutes = initialMinutes;
    int tempSeconds = initialSeconds;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Configurar Duración',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          Container(
            height: 200,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Selector de Horas
                _TimePickerColumn(
                  label: 'HORAS',
                  initialValue: initialHours,
                  maxValue: 23,
                  onChanged: (value) => tempHours = value,
                ),
                const Text(
                  ':',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                // Selector de Minutos
                _TimePickerColumn(
                  label: 'MINUTOS',
                  initialValue: initialMinutes,
                  maxValue: 59,
                  onChanged: (value) => tempMinutes = value,
                ),
                const Text(
                  ':',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                // Selector de Segundos
                _TimePickerColumn(
                  label: 'SEGUNDOS',
                  initialValue: initialSeconds,
                  maxValue: 59,
                  onChanged: (value) => tempSeconds = value,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // *** BOTÓN CORREGIDO ***
          ElevatedButton(
            onPressed: () {
              final newDuration = Duration(
                hours: tempHours,
                minutes: tempMinutes,
                seconds: tempSeconds,
              );
              if (newDuration.inSeconds == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('La duración debe ser mayor a cero.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }
              setState(() {
                _initialDuration = newDuration;
                _remainingDuration = newDuration;
                _countdownDisplay = _formatDuration(newDuration);
                _mode = TimerMode.countdown;
                _state = TimerState.running; // FIX: Establecer estado a running
              });

              _startCountdown(); // FIX: Iniciar el temporizador
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
            ),
            child: const Text(
              'Comenzar Temporizador',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerDisplay(String timeDisplay, {required bool isStopwatch}) {
    // ... (Sin cambios significativos, solo usa las variables de color de instancia)
    final isFinished = _state == TimerState.finished;

    // Lógica para formatear la visualización
    List<String> parts;
    String mainTime;
    String subTime = '';

    if (isStopwatch) {
      // Formato MM:SS:MMM
      parts = timeDisplay.split(':');
      mainTime = '${parts[0]}:${parts[1]}';
      subTime = parts.length > 2 ? ':${parts[2]}' : ':000';
    } else {
      // Formato HH:MM:SS
      parts = timeDisplay.split(':');
      mainTime = parts.sublist(0, 2).join(':'); // HH:MM
      subTime = parts.length > 2 ? ':${parts[2]}' : ':00'; // :SS
    }

    final display = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // HH:MM / MM:SS (Color principal)
        Text(
          mainTime,
          style: TextStyle(
            fontSize: 68,
            fontWeight: FontWeight.w100,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: isFinished ? Colors.greenAccent : Colors.white,
          ),
        ),
        // SS o Milisegundos (Color de Acento)
        Text(
          subTime,
          style: TextStyle(
            fontSize: isStopwatch ? 40 : 68,
            fontWeight: isStopwatch ? FontWeight.w100 : FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: isFinished ? Colors.greenAccent : primaryColor,
          ),
        ),
      ],
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Indicador de Modo
        Text(
          isStopwatch ? 'CRONÓMETRO' : 'TEMPORIZADOR',
          style: const TextStyle(
            color: Colors.white70,
            letterSpacing: 1.5,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),

        // Tarjeta de Display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
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
          child: display,
        ),
        const SizedBox(height: 40),

        // Botón de Reiniciar
        if (_state != TimerState.running)
          ElevatedButton(
            onPressed: isStopwatch ? _resetStopwatch : _resetCountdown,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Reiniciar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

        // Espacio para mantener la consistencia del layout cuando el botón de Reiniciar está oculto
        if (_state == TimerState.running) const SizedBox(height: 44),
      ],
    );
  }

  // --- Widget Principal (Build) ---

  @override
  Widget build(BuildContext context) {
    // Definiciones del AppBar y FAB basadas en el modo
    Widget? currentBody;
    String title;

    if (_mode == TimerMode.selection) {
      currentBody = _buildSelectionScreen();
      title = 'Medir el Tiempo';
    } else if (_mode == TimerMode.countdown && _state == TimerState.initial) {
      currentBody = _buildSetupScreen();
      title = 'Configurar Temporizador';
    } else {
      final isStopwatch = _mode == TimerMode.stopwatch;
      title = isStopwatch ? 'Cronómetro' : 'Temporizador';

      String displayTime = isStopwatch
          ? _progressiveDisplay
          : _countdownDisplay;

      if (_state == TimerState.finished) {
        displayTime = _formatDuration(
          Duration.zero,
        ); // Muestra 00:00:00 cuando termina
      }

      currentBody = _buildTimerDisplay(displayTime, isStopwatch: isStopwatch);
    }

    // Icono del FAB
    IconData fabIcon;
    Color fabColor;
    if (_state == TimerState.running) {
      fabIcon = Icons.pause_rounded;
      fabColor = accentColor;
    } else {
      fabIcon = Icons.play_arrow_rounded;
      fabColor = primaryColor;
    }

    // Condición para mostrar FAB:
    // 1. Siempre en modo Cronómetro (progresivo), sin importar el estado.
    // 2. En modo Temporizador (regresivo), si el estado es running o paused.
    bool showFab =
        _mode == TimerMode.stopwatch ||
        (_mode == TimerMode.countdown &&
            (_state == TimerState.running || _state == TimerState.paused));

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: _mode != TimerMode.selection
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBackToSelection,
              )
            : null,
        actions: const [],
      ),
      body: Center(child: currentBody),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: showFab
          ? FloatingActionButton.large(
              onPressed: _togglePlayPause,
              backgroundColor: fabColor,
              foregroundColor: Colors.black,
              child: Icon(fabIcon, size: 48),
            )
          : null,
    );
  }
}

// --- Widgets Auxiliares ---

class _SelectionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SelectionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8)],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePickerColumn extends StatefulWidget {
  final String label;
  final int initialValue;
  final int maxValue;
  final ValueChanged<int> onChanged;

  const _TimePickerColumn({
    required this.label,
    required this.initialValue,
    required this.maxValue,
    required this.onChanged,
  });

  @override
  State<_TimePickerColumn> createState() => _TimePickerColumnState();
}

class _TimePickerColumnState extends State<_TimePickerColumn> {
  late FixedExtentScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    int initialIndex = widget.initialValue.clamp(0, widget.maxValue);
    _scrollController = FixedExtentScrollController(initialItem: initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Expanded(
            child: CupertinoPicker(
              scrollController: _scrollController,
              itemExtent: 40,
              looping: true,
              onSelectedItemChanged: (index) {
                widget.onChanged(index);
              },
              children: List<Widget>.generate(widget.maxValue + 1, (index) {
                return Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      color: Theme.of(context).primaryColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                );
              }),
            ),
          ),
          Text(
            widget.label,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
