import 'package:flutter/foundation.dart';

class EventosApp {
  static final ValueNotifier<int> alertHistoryVersion = ValueNotifier<int>(0);

  static void incrementarHistorialAlertas() {
    alertHistoryVersion.value++;
  }
}
