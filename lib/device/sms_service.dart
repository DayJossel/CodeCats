import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:another_telephony/telephony.dart';

class SmsService {
  static final Telephony _telephony = Telephony.instance;

  /// Pide permisos SMS/Teléfono a nivel plugin y OS.
  static Future<void> ensureSmsAndPhonePermissions() async {
    // Si usas algún check de another_telephony, déjalo; aquí solo muestro un flag.
    final pluginOk = true;

    // 1) Lee el status actual
    final sms = await Permission.sms.status;
    final phone = await Permission.phone.status;

    // ❌ Antes: sms.status / phone.status   ✅ Ahora: imprime el enum o usa .isGranted
    debugPrint('[SMS] perms pluginOk=$pluginOk sms=$sms phone=$phone');

    // 2) Solicita si hace falta
    if (!sms.isGranted) {
      final r = await Permission.sms.request();
      if (!r.isGranted) throw Exception('Permiso SMS denegado por el usuario.');
    }

    if (!phone.isGranted) {
      final r = await Permission.phone.request();
      if (!r.isGranted) throw Exception('Permiso Teléfono denegado por el usuario.');
    }
  }

  /// Envío silencioso a un número **exacto** (sin normalización).
  /// Usa multipart para mensajes largos/Unicode.
  static Future<void> send({
    required String to,
    required String message,
  }) async {
    debugPrint('[SMS] Intento enviar a: $to  (len=${to.length})');
    final completer = Completer<SendStatus>();

    await _telephony.sendSms(
      to: to,
      message: message,
      isMultipart: true, // por emojis/acentos y mensajes >70 UCS-2 :contentReference[oaicite:2]{index=2}
      statusListener: (SendStatus status) {
        debugPrint('[SMS] statusListener: $status');
        if (!completer.isCompleted) completer.complete(status);
      },
    );

    // ⚠️ Antes dábamos SENT si no había callback; ahora lo tratamos como **FALLO**
    SendStatus? status;
    try {
      status = await completer.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      debugPrint('[SMS] sin callback en 10s — lo consideramos FALLO');
      status = null;
    }

    if (status != SendStatus.SENT && status != SendStatus.DELIVERED) {
      debugPrint('[SMS] ERROR estado final: $status');
      throw Exception('SMS no enviado (estado: $status)');
    }
    debugPrint('[SMS] OK estado final: $status');
  }

  /// Intenta varios formatos MX y si **todas** fallan, abre la app de SMS del sistema.
  static Future<void> sendFlexibleMx({
    required String rawPhone,
    required String message,
    bool fallbackToDefaultAppIfAllFail = true,
  }) async {
    final clean = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final candidates = <String>[];

    if (clean.startsWith('+')) {
      candidates.add(clean);
    } else if (clean.length == 10) {
      candidates..add(clean)..add('52$clean')..add('+52$clean');
    } else if (clean.length == 12 && clean.startsWith('52')) {
      candidates..add(clean)..add('+$clean');
    } else {
      candidates..add(clean);
      if (!clean.startsWith('+')) candidates.add('+$clean');
    }

    debugPrint('[SMS] raw="$rawPhone" -> candidatos=$candidates');

    Exception? lastError;
    for (final cand in candidates) {
      try {
        await send(to: cand, message: message);
        debugPrint('[SMS] Envío OK con formato: $cand');
        return;
      } catch (e) {
        debugPrint('[SMS] Falló con "$cand": $e');
        lastError = (e is Exception) ? e : Exception(e.toString());
      }
    }

    if (fallbackToDefaultAppIfAllFail) {
      final fallback = clean.startsWith('+')
          ? clean
          : (clean.length == 10 ? '+52$clean' : clean);
      debugPrint('[SMS] Todas fallaron, abro composer por defecto a $fallback');
      await _telephony.sendSmsByDefaultApp(
        to: fallback,
        message: message,
      ); // doc plugin: método de fallback :contentReference[oaicite:3]{index=3}
      return;
    }

    throw lastError ?? Exception('No se pudo enviar SMS a $rawPhone');
  }
}
