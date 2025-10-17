import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';

class SmsService {
  static final Telephony _telephony = Telephony.instance;

  /// Pide ambos permisos (varios OEM lo requieren para enviar):
  /// - SEND_SMS (Permission.sms)
  /// - READ_PHONE_STATE (Permission.phone)
  static Future<void> ensureSmsAndPhonePermissions() async {
    final sms = await Permission.sms.request();
    final phone = await Permission.phone.request();
    if (!sms.isGranted || !phone.isGranted) {
      throw Exception('Permisos de SMS o Teléfono denegados.');
    }
  }

  /// Envía un SMS y espera el callback del módem (SENT/DELIVERED).
  static Future<void> send({
    required String to,
    required String message,
  }) async {
    final completer = Completer<SendStatus>();

    await _telephony.sendSms(
      to: to,
      message: message,
      statusListener: (SendStatus status) {
        if (!completer.isCompleted) completer.complete(status);
      },
    );

    // Espera el callback hasta 10s (algunos OEM no lo disparan).
    SendStatus status;
    try {
      status = await completer.future.timeout(const Duration(seconds: 10));
    } catch (_) {
      status = SendStatus.SENT; // fallback razonable
    }

    if (status != SendStatus.SENT && status != SendStatus.DELIVERED) {
      throw Exception('SMS no enviado (estado: $status)');
    }
  }
}
