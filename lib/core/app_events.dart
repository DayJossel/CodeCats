import 'package:flutter/foundation.dart';

class AppEvents {
  /// Incrementa cuando se crea un nuevo historial de alerta.
  static final ValueNotifier<int> alertHistoryVersion = ValueNotifier<int>(0);

  static void bumpAlertHistory() {
    alertHistoryVersion.value++;
  }
}
