import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';

class SmsService {
  static final Telephony _telephony = Telephony.instance;

  /// Asegura permiso SEND_SMS. Lanza Exception si no se concede.
  static Future<void> ensureSmsPermission() async {
    final status = await Permission.sms.request();
    if (!status.isGranted) {
      throw Exception('Permiso para enviar SMS denegado.');
    }
  }

  /// Envía 1 SMS silencioso (sin abrir app de mensajes).
  static Future<void> send({
    required String to,
    required String message,
  }) async {
    await _telephony.sendSms(
      to: to,
      message: message,
    );
  }
}
