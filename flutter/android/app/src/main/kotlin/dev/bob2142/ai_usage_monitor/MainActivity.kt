package dev.bob2142.ai_usage_monitor

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "usageledger/device"
        private const val SYNC_ACTION = "dev.bob2142.ai_usage_monitor.SYNC"
    }

    private var deviceChannel: MethodChannel? = null
    private var pendingSync = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        deviceChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        "consumeSyncNow" -> {
                            val requested = pendingSync || intent.action == SYNC_ACTION
                            pendingSync = false
                            setIntent(Intent(intent).apply { action = null })
                            result.success(requested)
                        }

                        "openBatterySettings" -> {
                            try {
                                startActivity(
                                    Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
                                )
                                result.success(true)
                            } catch (_: Exception) {
                                try {
                                    startActivity(
                                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                            data = Uri.parse("package:$packageName")
                                        },
                                    )
                                    result.success(true)
                                } catch (_: Exception) {
                                    result.success(false)
                                }
                            }
                        }

                        else -> result.notImplemented()
                    }
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == SYNC_ACTION) {
            if (deviceChannel == null) {
                pendingSync = true
            } else {
                deviceChannel?.invokeMethod("syncNow", null)
            }
        }
    }
}
