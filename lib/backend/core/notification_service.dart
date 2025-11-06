// lib/core/notification_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class ServicioNotificaciones {
  ServicioNotificaciones._internal();
  static final ServicioNotificaciones instancia = ServicioNotificaciones._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _inicializado = false;

  // Canal nativo para permisos de alarmas exactas (MainActivity.kt)
  static const MethodChannel _alarmPerms = MethodChannel('chita/exact_alarm');

  // Canal Android de notificaciones
  static const AndroidNotificationChannel _raceChannel = AndroidNotificationChannel(
    'race_reminders_v2',
    'Recordatorios de carreras',
    description: 'Notificaciones 2 horas antes de cada carrera',
    importance: Importance.high,
    playSound: true,
  );

  // Registro anti-duplicados: id -> instante programado (ms epoch del remindAt)
  static const String _regKey = 'notif_registry_v1';

  String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  Future<void> inicializar() async {
    if (_inicializado) return;

    tzdata.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      final tzName = (localTz is String)
          ? localTz
          : (localTz as dynamic).identifier ?? localTz.toString();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _alTocarNotificacion,
      onDidReceiveBackgroundNotificationResponse: _alTocarNotificacion,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_raceChannel);

    _inicializado = true;
  }

  Future<void> asegurarPermisos() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    if (Platform.isAndroid) {
      final canExact = await _puedeProgramarExacto();
      if (!canExact) {
        await _solicitarPermisoAlarmaExactaUI();
      }
    }
  }

  Future<void> solicitarPermisoNotificaciones() => asegurarPermisos();

  static void _alTocarNotificacion(NotificationResponse _) {
    // Intencionalmente sin logs en release.
  }

  Future<bool> _puedeProgramarExacto() async {
    if (!Platform.isAndroid) return true;
    try {
      final ok = await _alarmPerms.invokeMethod<bool>('canScheduleExactAlarms');
      return ok ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _solicitarPermisoAlarmaExactaUI() async {
    if (!Platform.isAndroid) return;
    try {
      await _alarmPerms.invokeMethod('requestExactAlarmPermission');
    } catch (_) {}
  }

  // ===== Registro anti-duplicados =====
  Future<Map<String, int>> _cargarRegistro() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_regKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _guardarRegistro(Map<String, int> reg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_regKey, jsonEncode(reg));
  }

  /// Agenda UNA SOLA notificación por carrera exactamente 2h antes.
  /// - Si ya pasó ese momento (o falta < 2h) => NO agenda.
  /// - Antes de agendar: cancela por ID para evitar duplicados.
  /// - Usa registro local para omitir si ya está agendada al mismo instante.
  Future<bool> programarRecordatorioCarrera({
    required int raceId,
    required String title,
    required DateTime raceDateTimeLocal,
  }) async {
    await inicializar();
    await asegurarPermisos();

    final now = DateTime.now();
    final remindAt = raceDateTimeLocal.subtract(const Duration(hours: 2));

    // ❌ No agendar si llegamos tarde o es exactamente ahora
    if (!remindAt.isAfter(now)) {
      await cancelarRecordatorioCarrera(raceId); // por si hubiese una previa
      return false;
    }

    final id = _idParaCarrera(raceId);
    final tzWhen = tz.TZDateTime.from(remindAt, tz.local);
    final canExact = await _puedeProgramarExacto();
    final mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    // Anti-duplicados: si ya está agendada para ese instante exacto, omitimos
    final reg = await _cargarRegistro();
    final key = id.toString();
    final targetMs = remindAt.millisecondsSinceEpoch;
    final prevMs = reg[key];
    if (prevMs != null && prevMs == targetMs) {
      return true;
    }

    // Cancelar por ID para garantizar 1 sola
    await _plugin.cancel(id);

    const androidDetails = AndroidNotificationDetails(
      'race_reminders_v2',
      'Recordatorios de carreras',
      channelDescription: 'Notificaciones 2 horas antes de cada carrera',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      styleInformation: BigTextStyleInformation(''),
      ticker: 'Recordatorio de carrera',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await _plugin.zonedSchedule(
        id,
        'Recordatorio de carrera',
        'Tu carrera "$title" es en 2 horas.',
        tzWhen,
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        payload: raceId.toString(),
      );
      // Guarda en registro
      reg[key] = targetMs;
      await _guardarRegistro(reg);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cancela y vuelve a agendar (respetando reglas de 2h antes y anti-duplicado)
  Future<void> reprogramarRecordatorioCarrera({
    required int raceId,
    required String title,
    required DateTime raceDateTimeLocal,
  }) async {
    await cancelarRecordatorioCarrera(raceId);
    await programarRecordatorioCarrera(
      raceId: raceId,
      title: title,
      raceDateTimeLocal: raceDateTimeLocal,
    );
  }

  Future<void> cancelarRecordatorioCarrera(int raceId) async {
    await inicializar();
    final id = _idParaCarrera(raceId);
    await _plugin.cancel(id);
    // quita del registro
    final reg = await _cargarRegistro();
    if (reg.remove(id.toString()) != null) {
      await _guardarRegistro(reg);
    }
  }

  // ==== Utilidades ====

  Future<void> mostrarPruebaInmediata() async {
    await inicializar();
    const androidDetails = AndroidNotificationDetails(
      'race_reminders_v2',
      'Recordatorios de carreras',
      channelDescription: 'Notificaciones 2 horas antes de cada carrera',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.show(
      999002,
      'Notificación inmediata',
      'Si ves esto, las notificaciones están habilitadas.',
      details,
      payload: 'immediate',
    );
  }

  Future<List<PendingNotificationRequest>> pendientes() async {
    return _plugin.pendingNotificationRequests();
  }

  Future<void> cancelarTodas() async {
    await _plugin.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_regKey); // limpia registro
  }

  int _idParaCarrera(int raceId) => 100000 + ((raceId.abs()) % 900000);
}
