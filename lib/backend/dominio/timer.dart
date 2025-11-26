// lib/backend/dominio/timer.dart
import 'dart:async';

/// Modos de funcionamiento del timer de entrenamiento.
enum TimerMode { selection, countdown, stopwatch }

/// Estado actual del timer.
enum TimerState { initial, running, paused, finished }

/// Lógica pura del temporizador / cronómetro.
///
/// No depende de Flutter. Expone callbacks [onTick] y [onFinished]
/// para que la UI pueda reaccionar (hacer setState, mostrar snackbars, etc.).
class TimerUC {
  TimerMode mode;
  TimerState state;

  // Cronómetro (progresivo)
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _progressiveTimer;

  // Cuenta regresiva
  Duration initialDuration;
  Duration remainingDuration;
  Timer? _countdownTimer;

  final void Function()? onTick;
  final void Function()? onFinished;

  TimerUC({
    this.onTick,
    this.onFinished,
    Duration initialCountdown = const Duration(minutes: 5),
  })  : mode = TimerMode.selection,
        state = TimerState.initial,
        initialDuration = initialCountdown,
        remainingDuration = initialCountdown;

  // ===== Getters de visualización =====

  /// Texto formateado del cronómetro (MM:SS:MMM).
  String get progressiveDisplay =>
      formatMilliseconds(_stopwatch.elapsedMilliseconds);

  /// Texto formateado de la cuenta regresiva (HH:MM:SS).
  String get countdownDisplay => formatDuration(remainingDuration);

  // ===== Selección / navegación de modos =====

  void selectMode(TimerMode newMode) {
    _cancelTimers();
    if (newMode == TimerMode.stopwatch) {
      _stopwatch
        ..stop()
        ..reset();
    } else if (newMode == TimerMode.countdown) {
      remainingDuration = initialDuration;
    }
    mode = newMode;
    state = TimerState.initial;
    _notifyTick();
  }

  void goBackToSelection() {
    _cancelTimers();
    _stopwatch
      ..stop()
      ..reset();
    remainingDuration = initialDuration;
    mode = TimerMode.selection;
    state = TimerState.initial;
    _notifyTick();
  }

  // ===== Configuración de duración =====

  void setCountdownDuration(Duration d) {
    initialDuration = d;
    remainingDuration = d;
    if (state == TimerState.initial || state == TimerState.finished) {
      _notifyTick();
    }
  }

  // ===== Cronómetro (progresivo) =====

  void startStopwatch() {
    mode = TimerMode.stopwatch;
    state = TimerState.running;
    _stopwatch.start();
    _progressiveTimer?.cancel();
    _progressiveTimer =
        Timer.periodic(const Duration(milliseconds: 10), (_) => _notifyTick());
    _notifyTick();
  }

  void pauseStopwatch() {
    if (state != TimerState.running || mode != TimerMode.stopwatch) return;
    _stopwatch.stop();
    _progressiveTimer?.cancel();
    state = TimerState.paused;
    _notifyTick();
  }

  void resetStopwatch() {
    _progressiveTimer?.cancel();
    _stopwatch
      ..stop()
      ..reset();
    state = TimerState.initial;
    mode = TimerMode.stopwatch;
    _notifyTick();
  }

  // ===== Cuenta regresiva =====

  void startCountdown() {
    mode = TimerMode.countdown;
    state = TimerState.running;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingDuration.inSeconds > 0) {
        remainingDuration -= const Duration(seconds: 1);
        _notifyTick();
      } else {
        _countdownTimer?.cancel();
        state = TimerState.finished;
        _notifyTick();
        onFinished?.call();
      }
    });
    _notifyTick();
  }

  void pauseCountdown() {
    if (state != TimerState.running || mode != TimerMode.countdown) return;
    _countdownTimer?.cancel();
    state = TimerState.paused;
    _notifyTick();
  }

  void resetCountdown() {
    _countdownTimer?.cancel();
    remainingDuration = initialDuration;
    state = TimerState.initial;
    mode = TimerMode.countdown;
    _notifyTick();
  }

  // ===== Limpieza =====

  void dispose() {
    _cancelTimers();
  }

  void _cancelTimers() {
    _progressiveTimer?.cancel();
    _countdownTimer?.cancel();
  }

  void _notifyTick() {
    if (onTick != null) {
      onTick!();
    }
  }

  // ===== Utilidades de formato =====

  static String formatMilliseconds(int ms) {
    final minutes = (ms ~/ 60000) % 60;
    final seconds = (ms ~/ 1000) % 60;
    final milliseconds = ms % 1000;
    return '${_twoDigits(minutes)}:${_twoDigits(seconds)}:${_threeDigits(milliseconds)}';
  }

  static String formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${_twoDigits(hours)}:${_twoDigits(minutes)}:${_twoDigits(seconds)}';
  }

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');
  static String _threeDigits(int n) => n.toString().padLeft(3, '0');
}
