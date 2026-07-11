package gt.edu.miumg.sire

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Puente entre Flutter y el servicio nativo que detecta las 3 pulsaciones del
 * botón de encendido.
 *
 *  - MethodChannel `sire/power_control`: iniciar/detener el servicio y gestionar
 *    la exención de optimización de batería.
 *  - EventChannel  `sire/power_events`:  emite `sos_triggered` al detectar el patrón.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, CONTROL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDetection" -> {
                    startPowerService()
                    result.success(true)
                }
                "stopDetection" -> {
                    stopPowerService()
                    result.success(true)
                }
                "isIgnoringBatteryOptimizations" ->
                    result.success(isIgnoringBatteryOptimizations())
                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    PowerButtonEvents.sink = events
                }

                override fun onCancel(arguments: Any?) {
                    PowerButtonEvents.sink = null
                }
            },
        )
    }

    private fun startPowerService() {
        val intent = Intent(this, PowerButtonService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopPowerService() {
        stopService(Intent(this, PowerButtonService::class.java))
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        return pm.isIgnoringBatteryOptimizations(packageName)
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (isIgnoringBatteryOptimizations()) return
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:$packageName")
        }
        runCatching { startActivity(intent) }
    }

    companion object {
        private const val CONTROL_CHANNEL = "sire/power_control"
        private const val EVENT_CHANNEL = "sire/power_events"
    }
}
