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
                    // Guarda uid, nombre y aldea del usuario en sesión para que el
                    // servicio nativo etiquete la alerta (idUsuario, nombreUsuario,
                    // aldea) al escribir en Firestore y la rutee a su COCODE.
                    val uid = call.argument<String>("uid") ?: ""
                    val nombre = call.argument<String>("nombre") ?: ""
                    val aldea = call.argument<String>("aldea") ?: ""
                    getSharedPreferences(PowerButtonService.PREFS, MODE_PRIVATE)
                        .edit()
                        .putString(PowerButtonService.KEY_UID, uid)
                        .putString(PowerButtonService.KEY_NOMBRE, nombre)
                        .putString(PowerButtonService.KEY_ALDEA, aldea)
                        .apply()
                    startPowerService()
                    result.success(true)
                }
                "stopDetection" -> {
                    stopPowerService()
                    result.success(true)
                }
                "isIgnoringBatteryOptimizations" ->
                    result.success(isIgnoringBatteryOptimizations())
                "isDetectionRunning" ->
                    result.success(PowerButtonService.isRunning)
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

        // Monitoreo de alertas para autoridades (COCODE / Municipalidad):
        // arranca al iniciar sesión una autoridad, se detiene al cerrarla.
        MethodChannel(messenger, MONITOR_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startMonitor" -> {
                    // Guarda el filtro del monitoreo para que el servicio arme la
                    // consulta correcta: Municipalidad = todas; COCODE = solo su
                    // aldea; ciudadano = solo los uids de sus contactos (RF-11).
                    val todos = call.argument<Boolean>("todos") ?: true
                    val contactos =
                        call.argument<List<String>>("contactos") ?: emptyList()
                    val aldea = call.argument<String>("aldea") ?: ""
                    getSharedPreferences(AlertMonitorService.PREFS, MODE_PRIVATE)
                        .edit()
                        .putBoolean(AlertMonitorService.KEY_TODOS, todos)
                        .putStringSet(
                            AlertMonitorService.KEY_CONTACTOS,
                            contactos.toSet(),
                        )
                        .putString(AlertMonitorService.KEY_ALDEA, aldea)
                        .apply()
                    startMonitorService()
                    result.success(true)
                }
                "stopMonitor" -> {
                    stopMonitorService()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
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

    private fun startMonitorService() {
        val intent = Intent(this, AlertMonitorService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopMonitorService() {
        stopService(Intent(this, AlertMonitorService::class.java))
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
        private const val MONITOR_CHANNEL = "sire/alert_monitor"
    }
}
