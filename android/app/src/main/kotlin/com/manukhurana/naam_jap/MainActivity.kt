package com.manukhurana.naam_jap

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var volumeChannel: MethodChannel? = null
    private var dndChannel: MethodChannel? = null
    private var previousInterruptionFilter: Int = NotificationManager.INTERRUPTION_FILTER_ALL

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        volumeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.manukhurana.naam_jap/volume")
        dndChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.manukhurana.naam_jap/dnd")
        dndChannel?.setMethodCallHandler { call, result ->
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            when(call.method) {
                "hasPermission" -> {
                    result.success(nm.isNotificationPolicyAccessGranted)
                }
                "requestPermission" -> {
                    if (!nm.isNotificationPolicyAccessGranted) {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                        startActivity(intent)
                    }
                    result.success(nm.isNotificationPolicyAccessGranted)
                }
                "enableDnd" -> {
                    if (nm.isNotificationPolicyAccessGranted) {
                        previousInterruptionFilter = nm.currentInterruptionFilter
                        nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
                        result.success(true);
                    } else {
                        result.success(false);
                    }
                }
                "disableDnd" -> {
                    if (nm.isNotificationPolicyAccessGranted) {
                        nm.setInterruptionFilter(previousInterruptionFilter)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.action == KeyEvent.ACTION_DOWN && event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            volumeChannel?.invokeMethod("volumeUpPressed", null)
            return true
        }
        return super.dispatchKeyEvent(event)
    }
}
