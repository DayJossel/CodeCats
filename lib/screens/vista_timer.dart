// lib/screens/vista_timer.dart
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../main.dart'; // (aquí si quieres puedes quitarlo si no lo usas en otros lados)
import '../backend/dominio/timer.dart';

class VistaTimer extends StatefulWidget {
  const VistaTimer({super.key});

  @override
  State<VistaTimer> createState() => _EstadoVistaTimer();
}

class _EstadoVistaTimer extends State<VistaTimer> {
  late TimerUC _timerUC;

  // Colores locales para usar sin Theme.of(context)
  final Color primaryColor = const Color(0xFFFFC700);
  final Color accentColor = const Color(0xFFFE526E); // SOS
  final Color backgroundColor = const Color(0xFF121212);
  final Color cardColor = const Color(0xFF1E1E1E);

  TimerMode get _mode => _timerUC.mode;
  TimerState get _state => _timerUC.state;

  @override
  void initState() {
    super.initState();
    _timerUC = TimerUC(
      onTick: () {
        if (mounted) setState(() {});
      },
      onFinished: () {
        if (mounted) _notifyFinished();
      },
    );
  }

  @override
  void dispose() {
    _timerUC.dispose();
    super.dispose();
  }

  // ===== Callbacks de UI sobre la capa de dominio =====

  void _selectMode(TimerMode mode) {
    _timerUC.selectMode(mode);
  }

  void _goBackToSelection() {
    _timerUC.goBackToSelection();
  }

  void _togglePlayPause() {
    if (_mode == TimerMode.stopwatch) {
      if (_state == TimerState.running) {
        _timerUC.pauseStopwatch();
      } else {
        _timerUC.startStopwatch();
      }
    } else if (_mode == TimerMode.countdown) {
      if (_state == TimerState.running) {
        _timerUC.pauseCountdown();
      } else if (_state == TimerState.initial || _state == TimerState.paused) {
        _timerUC.startCountdown();
      }
    }
  }

  void _notifyFinished() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Tiempo terminado! ¡Objetivo completado!'),
        duration: Duration(seconds: 4),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ===== Vistas =====

  Widget _buildSelectionScreen() {
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
    final initial = _timerUC.initialDuration;
    int initialHours = initial.inHours;
    int initialMinutes = initial.inMinutes.remainder(60);
    int initialSeconds = initial.inSeconds.remainder(60);

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

              _timerUC.setCountdownDuration(newDuration);
              _timerUC.startCountdown();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              padding:
                  const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
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

  Widget _buildTimerDisplay(String timeDisplay,
      {required bool isStopwatch}) {
    final isFinished = _state == TimerState.finished;

    List<String> parts;
    String mainTime;
    String subTime = '';

    if (isStopwatch) {
      // MM:SS:MMM
      parts = timeDisplay.split(':');
      mainTime = '${parts[0]}:${parts[1]}';
      subTime = parts.length > 2 ? ':${parts[2]}' : ':000';
    } else {
      // HH:MM:SS
      parts = timeDisplay.split(':');
      mainTime = parts.sublist(0, 2).join(':'); // HH:MM
      subTime = parts.length > 2 ? ':${parts[2]}' : ':00'; // :SS
    }

    final display = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          mainTime,
          style: TextStyle(
            fontSize: 68,
            fontWeight: FontWeight.w100,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: isFinished ? Colors.greenAccent : Colors.white,
          ),
        ),
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
        Text(
          isStopwatch ? 'CRONÓMETRO' : 'TEMPORIZADOR',
          style: const TextStyle(
            color: Colors.white70,
            letterSpacing: 1.5,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
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
        if (_state != TimerState.running)
          ElevatedButton(
            onPressed: isStopwatch
                ? _timerUC.resetStopwatch
                : _timerUC.resetCountdown,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Reiniciar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        if (_state == TimerState.running) const SizedBox(height: 44),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget currentBody;
    String title;

    if (_mode == TimerMode.selection) {
      currentBody = _buildSelectionScreen();
      title = 'Timer';
    } else if (_mode == TimerMode.countdown &&
        _state == TimerState.initial) {
      currentBody = _buildSetupScreen();
      title = 'Configurar Temporizador';
    } else {
      final isStopwatch = _mode == TimerMode.stopwatch;
      title = isStopwatch ? 'Cronómetro' : 'Temporizador';

      final displayTime = isStopwatch
          ? _timerUC.progressiveDisplay
          : _timerUC.countdownDisplay;

      currentBody = _buildTimerDisplay(
        displayTime,
        isStopwatch: isStopwatch,
      );
    }

    IconData fabIcon;
    Color fabColor;
    if (_state == TimerState.running) {
      fabIcon = Icons.pause_rounded;
      fabColor = accentColor;
    } else {
      fabIcon = Icons.play_arrow_rounded;
      fabColor = primaryColor;
    }

    final bool showFab = _mode == TimerMode.stopwatch ||
        (_mode == TimerMode.countdown &&
            (_state == TimerState.running ||
                _state == TimerState.paused));

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
      ),
      body: Center(child: currentBody),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
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

// ===== Widgets Auxiliares de UI =====

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
        color: Theme.of(context)
            .bottomNavigationBarTheme
            .backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 8),
        ],
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
    final initialIndex =
        widget.initialValue.clamp(0, widget.maxValue);
    _scrollController =
        FixedExtentScrollController(initialItem: initialIndex);
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
              children:
                  List<Widget>.generate(widget.maxValue + 1, (index) {
                return Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      color: Theme.of(context).primaryColor,
                      fontFeatures: const [
                        FontFeature.tabularFigures()
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          Text(
            widget.label,
            style:
                const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}