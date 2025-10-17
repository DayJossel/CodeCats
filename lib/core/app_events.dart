import 'package:flutter/foundation.dart';

class AppEvents {
  static final ValueNotifier<int> alertHistoryVersion = ValueNotifier<int>(0);

  static void bumpAlertHistory() {
    alertHistoryVersion.value++;
  }
}
