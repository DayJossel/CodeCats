// lib/core/notification_service.dart
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Canal nativo para permisos de alarmas exactas (ver MainActivity.kt)
  static const MethodChannel _alarmPerms = MethodChannel('chita/exact_alarm');

  // Canal Android de notificaciones
  static const AndroidNotificationChannel _raceChannel = AndroidNotificationChannel(
    'race_reminders_v2',
    'Recordatorios de carreras',
    description: 'Notificaciones 2 horas antes de cada carrera',
    importance: Importance.high,
    playSound: true,
  );

  // --- Helper para logs legibles
  String _fmt(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
           '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  Future<void> init() async {
    if (_initialized) return;

    // Zona horaria
    tzdata.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone(); // ej. America/Mexico_City
      final tzName = (localTz is String)
          ? localTz
          : (localTz as dynamic).identifier ?? localTz.toString();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (e) {
      debugPrint('[NOTIF] Zona horaria no disponible ($e). Usando UTC.');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // Init plugin
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTapNotification,
      onDidReceiveBackgroundNotificationResponse: _onTapNotification,
    );

    // Canal Android
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_raceChannel);

    _initialized = true;
  }

  Future<void> ensurePermissions() async {
    // Permiso de notificaciones (Android 13+) e iOS
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Verifica/solicita "alarmas exactas" (Android 12+)
    if (Platform.isAndroid) {
      final canExact = await _canScheduleExact();
      if (!canExact) {
        debugPrint('[NOTIF] El sistema NO permite alarmas exactas. Abriendo ajustes…');
        await _requestExactAlarmPermUI();
      }
    }
  }

  // Alias usado por tu main/UI
  Future<void> requestNotificationsPermission() => ensurePermissions();

  static void _onTapNotification(NotificationResponse response) {
    debugPrint('[NOTIF] Tap payload=${response.payload}');
  }

  Future<bool> _canScheduleExact() async {
    if (!Platform.isAndroid) return true;
    try {
      final ok = await _alarmPerms.invokeMethod<bool>('canScheduleExactAlarms');
      return ok ?? true;
    } catch (e) {
      // En versiones antiguas o si falla, asumimos true para no bloquear.
      debugPrint('[NOTIF] _canScheduleExact() fallo: $e');
      return true;
    }
  }

  Future<void> _requestExactAlarmPermUI() async {
    if (!Platform.isAndroid) return;
    try {
      await _alarmPerms.invokeMethod('requestExactAlarmPermission');
    } catch (e) {
      debugPrint('[NOTIF] requestExactAlarmPermission fallo: $e');
    }
  }

  /// Programa recordatorio 2 horas antes. Si faltan <2h, agenda en 1 min (pruebas).
  /// Usa EXACTA si el sistema lo permite; si no, cae a INEXACTA (que al menos sí dispara).
  Future<bool> scheduleRaceReminder({
    required int raceId,
    required String title,
    required DateTime raceDateTimeLocal,
  }) async {
    await init();
    await ensurePermissions();

    final now = DateTime.now();
    DateTime remindAt = raceDateTimeLocal.subtract(const Duration(hours: 2));
    bool fallback1min = false;
    if (!remindAt.isAfter(now)) {
      remindAt = now.add(const Duration(minutes: 1));
      fallback1min = true;
    }
    final tzWhen = tz.TZDateTime.from(remindAt, tz.local);

    final canExact = await _canScheduleExact();
    final mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    final debugMsg = fallback1min
        ? '[NOTIF] (fallback) "$title" se notificará a las ${_fmt(remindAt)} (local) en 1 min porque faltaban <2h. modo=${mode.name}'
        : '[NOTIF] "$title" se notificará a las ${_fmt(remindAt)} (local), 2h antes. modo=${mode.name}';
    debugPrint(debugMsg);

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
        _idForRace(raceId),
        'Recordatorio de carrera',
        'Tu carrera "$title" es en 2 horas.',
        tzWhen,
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        payload: raceId.toString(),
      );
      debugPrint('[NOTIF] Programada ${mode == AndroidScheduleMode.exactAllowWhileIdle ? 'EXACTA' : 'INEXACTA'} id=${_idForRace(raceId)} en $tzWhen');
      return true;
    } on PlatformException catch (e) {
      // Si intentamos exacta y explotó, reintentamos inexacta.
      if (mode == AndroidScheduleMode.exactAllowWhileIdle) {
        debugPrint('[NOTIF] Exacta falló: $e — reintentando INEXACTA…');
        try {
          await _plugin.zonedSchedule(
            _idForRace(raceId),
            'Recordatorio de carrera',
            'Tu carrera "$title" es en 2 horas.',
            tzWhen,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.wallClockTime,
            payload: raceId.toString(),
          );
          debugPrint('[NOTIF] Programada INEXACTA id=${_idForRace(raceId)} en $tzWhen');
          return true;
        } catch (e2) {
          debugPrint('[NOTIF] Inexacta también falló: $e2');
          return false;
        }
      } else {
        debugPrint('[NOTIF] Inexacta falló: $e');
        return false;
      }
    } catch (e) {
      debugPrint('[NOTIF] ERROR inesperado: $e');
      return false;
    }
  }

  Future<void> rescheduleRaceReminder({
    required int raceId,
    required String title,
    required DateTime raceDateTimeLocal,
  }) async {
    await cancelRaceReminder(raceId);
    await scheduleRaceReminder(
      raceId: raceId,
      title: title,
      raceDateTimeLocal: raceDateTimeLocal,
    );
  }

  Future<void> cancelRaceReminder(int raceId) async {
    await _plugin.cancel(_idForRace(raceId));
  }

  // ===== utilidades de depuración =====
  Future<bool> scheduleTestInSeconds(int seconds) async {
    await init();
    await ensurePermissions();

    final when = tz.TZDateTime.from(
      DateTime.now().add(Duration(seconds: seconds)),
      tz.local,
    );

    // ID único para no pisar notificaciones previas
    final int id = 990000 + (DateTime.now().microsecondsSinceEpoch % 90000);

    const androidDetails = AndroidNotificationDetails(
      'race_reminders_v2',
      'Recordatorios de carreras',
      channelDescription: 'Notificaciones 2 horas antes de cada carrera',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      styleInformation: BigTextStyleInformation(''),
      ticker: 'Test notification',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final canExact = await _canScheduleExact();
    final mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _plugin.zonedSchedule(
        id,
        'Prueba en ${seconds}s',
        'Si ves esto, el agendado (${mode.name}) funciona.',
        when,
        details,
        androidScheduleMode: mode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'test:$id',
      );
      debugPrint('[NOTIF][TEST] ${mode.name} programada id=$id at $when');
      return true;
    } catch (e) {
      debugPrint('[NOTIF][TEST] Error: $e');
      return false;
    }
  }

  Future<void> showImmediateTest() async {
    await init();
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

  Future<List<PendingNotificationRequest>> pending() async {
    return _plugin.pendingNotificationRequests();
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  int _idForRace(int raceId) => 100000 + ((raceId.abs()) % 900000);
}
