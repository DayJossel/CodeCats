import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:another_telephony/telephony.dart';

class ServicioSMS {
  static final Telephony _telephony = Telephony.instance;

  /// Pide permisos SMS/Teléfono a nivel plugin y OS.
  static Future<void> asegurarPermisosSmsYTelefono() async {
    // 1) Lee el status actual
    final sms = await Permission.sms.status;
    final phone = await Permission.phone.status;

    // 2) Solicita si hace falta
    if (!sms.isGranted) {
      final r = await Permission.sms.request();
      if (!r.isGranted) throw Exception('Permiso SMS denegado por el usuario.');
    }
    // (El permiso de teléfono puede ser requerido por algunos dispositivos/ROMs)
    if (!phone.isGranted) {
      await Permission.phone.request();
    }
  }

  /// Envío silencioso a un número **exacto** (sin normalización).
  /// Usa multipart para mensajes largos/Unicode.
  static Future<void> enviar({
    required String to,
    required String message,
  }) async {
    final completer = Completer<SendStatus>();

    await _telephony.sendSms(
      to: to,
      message: message,
      isMultipart: true, // por emojis/acentos y mensajes >70 UCS-2
      statusListener: (SendStatus status) {
        if (!completer.isCompleted) completer.complete(status);
      },
    );

    SendStatus? status;
    try {
      status = await completer.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      status = null;
    }

    if (status != SendStatus.SENT && status != SendStatus.DELIVERED) {
      throw Exception('SMS no enviado (estado: $status)');
    }
  }

  /// Intenta varios formatos MX y si **todas** fallan, abre la app de SMS del sistema.
  static Future<void> enviarFlexibleMx({
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

    Exception? lastError;
    for (final cand in candidates) {
      try {
        await enviar(to: cand, message: message);
        return;
      } catch (e) {
        lastError = (e is Exception) ? e : Exception(e.toString());
      }
    }

    if (fallbackToDefaultAppIfAllFail) {
      final fallback = clean.startsWith('+')
          ? clean
          : (clean.length == 10 ? '+52$clean' : clean);
      await _telephony.sendSmsByDefaultApp(
        to: fallback,
        message: message,
      );
      return;
    }

    throw lastError ?? Exception('No se pudo enviar SMS a $rawPhone');
  }
}