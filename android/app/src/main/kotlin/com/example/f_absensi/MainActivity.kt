package com.leryn.f_absensi

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.os.SystemClock
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

    private val CHANNEL = "uptime"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "getUptime" -> {
                    result.success(SystemClock.elapsedRealtime())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
