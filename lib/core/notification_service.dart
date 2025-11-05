// lib/core/notification_service.dart
import 'dart:async';
import 'dart:convert'; // ✅ necesario para jsonEncode/jsonDecode
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

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

    _initialized = true;
  }

  Future<void> ensurePermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    if (Platform.isAndroid) {
      final canExact = await _canScheduleExact();
      if (!canExact) {
        debugPrint('[NOTIF] El sistema NO permite alarmas exactas. Abriendo ajustes…');
        await _requestExactAlarmPermUI();
      }
    }
  }

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

  // ===== Registro anti-duplicados (simple y robusto) =====
  Future<Map<String, int>> _loadRegistry() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_regKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final Map<String, dynamic> decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (e) {
      debugPrint('[NOTIF] Registro corrupto, se reinicia. Error: $e');
      return {};
    }
  }

  Future<void> _saveRegistry(Map<String, int> reg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_regKey, jsonEncode(reg));
  }

  /// Agenda UNA SOLA notificación por carrera exactamente 2h antes.
  /// - Si ya pasó ese momento (o falta < 2h) => NO agenda.
  /// - Antes de agendar: cancela por ID para evitar duplicados.
  /// - Usa registro local para omitir si ya está agendada al mismo instante.
  Future<bool> scheduleRaceReminder({
    required int raceId,
    required String title,
    required DateTime raceDateTimeLocal,
  }) async {
    await init();
    await ensurePermissions();

    final now = DateTime.now();
    final remindAt = raceDateTimeLocal.subtract(const Duration(hours: 2));

    // ❌ No agendar si llegamos tarde o es exactamente ahora
    if (!remindAt.isAfter(now)) {
      debugPrint('[NOTIF] NO se agenda "$title": 2h-antes (${_fmt(remindAt)}) ya pasó o es ahora.');
      await cancelRaceReminder(raceId); // por si hubiese una previa
      return false;
    }

    final id = _idForRace(raceId);
    final tzWhen = tz.TZDateTime.from(remindAt, tz.local);
    final canExact = await _canScheduleExact();
    final mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    // Anti-duplicados: si ya está agendada para ese instante exacto, omitimos
    final reg = await _loadRegistry();
    final key = id.toString();
    final targetMs = remindAt.millisecondsSinceEpoch;
    final prevMs = reg[key];
    if (prevMs != null && prevMs == targetMs) {
      debugPrint('[NOTIF] Omito: ya estaba agendada id=$id @ ${_fmt(remindAt)}.');
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
      debugPrint('[NOTIF] Programada ${mode == AndroidScheduleMode.exactAllowWhileIdle ? 'EXACTA' : 'INEXACTA'} id=$id en ${_fmt(remindAt)}');
      // Guarda en registro
      reg[key] = targetMs;
      await _saveRegistry(reg);
      return true;
    } catch (e) {
      debugPrint('[NOTIF] ERROR al agendar: $e');
      return false;
    }
  }

  /// Cancela y vuelve a agendar (respetando reglas de 2h antes y anti-duplicado)
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
    await init();
    final id = _idForRace(raceId);
    await _plugin.cancel(id);
    // quita del registro
    final reg = await _loadRegistry();
    if (reg.remove(id.toString()) != null) {
      await _saveRegistry(reg);
    }
  }

  // ==== utilidades de depuración ====

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_regKey); // limpia registro
  }

  int _idForRace(int raceId) => 100000 + ((raceId.abs()) % 900000);
}
