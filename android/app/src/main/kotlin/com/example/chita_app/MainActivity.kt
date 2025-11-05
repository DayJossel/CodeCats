package com.example.chita_app

import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
  private val CHANNEL = "chita/exact_alarm"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "canScheduleExactAlarms" -> {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
              val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
              result.success(am.canScheduleExactAlarms())
            } else {
              result.success(true)
            }
          }
          "requestExactAlarmPermission" -> {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
              try {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                  data = Uri.parse("package:$packageName")
                  addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                result.success(true)
              } catch (e: Exception) {
                result.error("ERR", e.message, null)
              }
            } else {
              result.success(true)
            }
          }
          else -> result.notImplemented()
        }
      }
  }
}
