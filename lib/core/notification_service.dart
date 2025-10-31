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

  // Canal NUEVO para evitar configuraciones viejas del sistema
  static const AndroidNotificationChannel _raceChannel = AndroidNotificationChannel(
    'race_reminders_v2',
    'Recordatorios de carreras',
    description: 'Notificaciones 2 horas antes de cada carrera',
    importance: Importance.high,
    playSound: true,
  );

  Future<void> init() async {
    if (_initialized) return;

    // Zona horaria
    tzdata.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone(); // p.ej. America/Mexico_City
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
    // Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // iOS
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Android 12+: “exact alarms” si el plugin/SO lo soportan
    if (Platform.isAndroid) {
      final allowed = await _androidAreExactAlarmsAllowed();
      if (!allowed) {
        await _androidRequestExactAlarmsPermission();
      }
    }
  }

  // Alias usado por tu main/UI
  Future<void> requestNotificationsPermission() => ensurePermissions();

  static void _onTapNotification(NotificationResponse response) {
    debugPrint('[NOTIF] Tap payload=${response.payload}');
  }

  /// Programa recordatorio 2 horas antes. Si faltan <2h, se agenda en 1 minuto (para pruebas).
  /// Estrategia: intentar EXACTA; si falla por permiso, reintentar INEXACTA.
  Future<bool> scheduleRaceReminder({
    required int raceId,
    required String title,
    required DateTime raceDateTimeLocal,
  }) async {
    await init();

    final now = DateTime.now();
    DateTime remindAt = raceDateTimeLocal.subtract(const Duration(hours: 2));
    if (!remindAt.isAfter(now)) {
      remindAt = now.add(const Duration(minutes: 1));
    }
    final tzWhen = tz.TZDateTime.from(remindAt, tz.local);

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

    // 1) Intento EXACTO
    try {
      await _plugin.zonedSchedule(
        _idForRace(raceId),
        'Recordatorio de carrera',
        'Tu carrera "$title" es en 2 horas.',
        tzWhen,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        payload: raceId.toString(),
      );
      debugPrint('[NOTIF] Programada EXACTA raceId=$raceId en $tzWhen');
      return true;
    } on PlatformException catch (e) {
      debugPrint('[NOTIF] Exacta falló: $e — reintentando INEXACTA…');
      // 2) Reintento INEXACTO (no requiere permiso de alarmas exactas)
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
        debugPrint('[NOTIF] Programada INEXACTA raceId=$raceId en $tzWhen');
        return true;
      } catch (e2) {
        debugPrint('[NOTIF] Inexacta también falló: $e2');
        return false;
      }
    } catch (e) {
      debugPrint('[NOTIF] ERROR inesperado: $e');
      return false;
    }
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

    // --- Permiso de alarmas exactas en Android ---
    bool exactAllowed = true;
    if (Platform.isAndroid) {
      try {
        final android = _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final dynamic dyn = android;
        final res = await dyn?.areExactAlarmsAllowed();
        exactAllowed = res == true;
      } catch (_) {
        exactAllowed = false;
      }
    }

    if (!exactAllowed && Platform.isAndroid) {
      // Abre pantalla del sistema para que habilites "Alarmas exactas"
      try {
        final android = _plugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final dynamic dyn = android;
        await dyn?.requestExactAlarmsPermission();
      } catch (_) {
        // si el plugin no lo expone, lo ignoramos aquí (la inmediata de fallback igual saldrá)
      }

      // Fallback SOLO PARA PRUEBA: si estás en primer plano, muestra en N s aunque el SO bloquee alarmas
      Future.delayed(Duration(seconds: seconds), () async {
        await _plugin.show(
          id,
          'Prueba inmediata (${seconds}s)',
          'Esto es un fallback de prueba sin alarmas exactas.',
          details,
          payload: 'test_fallback:$id',
        );
      });
      debugPrint('[NOTIF][TEST] Fallback en ${seconds}s (sin alarmas exactas)');
      return true;
    }

    // Intento EXACTO
    try {
      await _plugin.zonedSchedule(
        id,
        'Prueba en ${seconds}s',
        'Si ves esto, el agendado exacto funciona.',
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'test:$id',
      );
      debugPrint('[NOTIF][TEST] EXACTA programada id=$id at $when');
      return true;
    } on PlatformException catch (e) {
      debugPrint('[NOTIF][TEST] Exacta falló: $e — reintentando INEXACTA…');
      try {
        await _plugin.zonedSchedule(
          id,
          'Prueba (inexacta) en ${seconds}s',
          'Si ves esto, el agendado inexacto funciona.',
          when,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'test_inexact:$id',
        );
        debugPrint('[NOTIF][TEST] INEXACTA programada id=$id at $when');
        return true;
      } catch (e2) {
        debugPrint('[NOTIF][TEST] Inexacta también falló: $e2');
        return false;
      }
    } catch (e) {
      debugPrint('[NOTIF][TEST] Error inesperado: $e');
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

  Future<void> requestExactAlarmsPermissionIfAvailable() async {
    await _androidRequestExactAlarmsPermission();
  }

  Future<void> openExactAlarmSettings() async {
    await _androidRequestExactAlarmsPermission();
  }

  int _idForRace(int raceId) => 100000 + (raceId % 900000);

  // ===== Helpers para “exact alarms” por invocación dinámica =====
  Future<bool> _androidAreExactAlarmsAllowed() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return false;
      final dynamic dyn = android;
      final result = await dyn.areExactAlarmsAllowed();
      if (result is bool) return result;
      return false;
    } catch (e) {
      debugPrint('[NOTIF] areExactAlarmsAllowed no disponible: $e');
      return false;
    }
  }

  Future<void> _androidRequestExactAlarmsPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return;
      final dynamic dyn = android;
      await dyn.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('[NOTIF] requestExactAlarmsPermission no disponible: $e');
    }
  }
}
