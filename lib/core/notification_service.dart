// lib/core/notification_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // ⬅️ para PlatformException
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const AndroidNotificationChannel _raceChannel = AndroidNotificationChannel(
    'race_reminders',
    'Recordatorios de carreras',
    description: 'Notificaciones 2 horas antes de cada carrera',
    importance: Importance.high,
    playSound: true,
  );

  Future<void> init() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      final tzName = (localTz is String)
          ? localTz
          : (localTz as dynamic).identifier ?? localTz.toString();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (e) {
      debugPrint('[NOTIF] Zona horaria no disponible ($e). Usando UTC.');
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
      onDidReceiveNotificationResponse: _onTapNotification,
      onDidReceiveBackgroundNotificationResponse: _onTapNotification,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_raceChannel);

    // Android 13+: pide permiso de notificaciones
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  static void _onTapNotification(NotificationResponse response) {
    debugPrint('[NOTIF] Tap payload=${response.payload}');
  }

  Future<void> requestNotificationsPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<bool> scheduleRaceReminder({
    required int raceId,
    required String title,
    required DateTime raceDateTimeLocal,
  }) async {
    await init(); // por si alguien llama sin inicializar

    // “Dos horas antes”, pero si ya pasó, prográmalo a 1 minuto (para pruebas es útil)
    DateTime remindAt = raceDateTimeLocal.subtract(const Duration(hours: 2));
    if (!remindAt.isAfter(DateTime.now())) {
      remindAt = DateTime.now().add(const Duration(minutes: 1));
    }

    final tz.TZDateTime tzWhen = tz.TZDateTime.from(remindAt, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'race_reminders',
      'Recordatorios de carreras',
      channelDescription: 'Notificaciones 2 horas antes de cada carrera',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      styleInformation: BigTextStyleInformation(''),
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
        // ⬇️ inexacta = NO requiere permiso SCHEDULE_EXACT_ALARM
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: raceId.toString(),
      );
      debugPrint('[NOTIF] Programada raceId=$raceId en $tzWhen');
      return true;
    } on PlatformException catch (e) {
      // Si el sistema no permite alarmas exactas u otro bloqueo, no reventamos el flujo
      debugPrint('[NOTIF] ERROR al programar: $e');
      return false;
    } catch (e) {
      debugPrint('[NOTIF] ERROR inesperado al programar: $e');
      return false;
    }
  }

  Future<void> cancelRaceReminder(int raceId) async {
    await _plugin.cancel(_idForRace(raceId));
  }

  int _idForRace(int raceId) => 100000 + (raceId % 900000);
}
