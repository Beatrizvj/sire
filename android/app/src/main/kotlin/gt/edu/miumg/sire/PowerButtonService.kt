package gt.edu.miumg.sire

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Servicio en primer plano que detecta el patrón de emergencia de SIRE.
 *
 * Android no permite interceptar la tecla de encendido (KEYCODE_POWER) sin ser
 * app de sistema/root. El método estándar es contar las alternancias de
 * pantalla (ACTION_SCREEN_ON / ACTION_SCREEN_OFF) que produce cada pulsación:
 * [REQUIRED_TOGGLES] alternancias dentro de [WINDOW_MS] disparan el SOS.
 *
 * Al detectar el patrón:
 *   1. Avisa a Flutter vía [PowerButtonEvents] (EventChannel).
 *   2. Muestra una notificación de alta prioridad como respaldo.
 */
class PowerButtonService : Service() {

    private val toggleTimestamps = ArrayDeque<Long>()
    private var screenReceiver: BroadcastReceiver? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        startForeground(ONGOING_NOTIFICATION_ID, buildOngoingNotification())
        registerScreenReceiver()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int =
        START_STICKY

    override fun onDestroy() {
        screenReceiver?.let { receiver -> runCatching { unregisterReceiver(receiver) } }
        screenReceiver = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // --- Detección ---

    private fun registerScreenReceiver() {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    Intent.ACTION_SCREEN_ON, Intent.ACTION_SCREEN_OFF -> onScreenToggle()
                }
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
        }
        ContextCompat.registerReceiver(
            this,
            receiver,
            filter,
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        screenReceiver = receiver
    }

    private fun onScreenToggle() {
        val now = System.currentTimeMillis()
        toggleTimestamps.addLast(now)
        while (toggleTimestamps.isNotEmpty() && now - toggleTimestamps.first() > WINDOW_MS) {
            toggleTimestamps.removeFirst()
        }
        if (toggleTimestamps.size >= REQUIRED_TOGGLES) {
            toggleTimestamps.clear()
            onPatternDetected()
        }
    }

    private fun onPatternDetected() {
        PowerButtonEvents.emit(EVENT_SOS)
        showAlertNotification()
    }

    // --- Notificaciones ---

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                ONGOING_CHANNEL_ID,
                "Detección SOS",
                NotificationManager.IMPORTANCE_LOW,
            ).apply { description = "Servicio que vigila el botón de encendido." },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                ALERT_CHANNEL_ID,
                "Alertas SOS",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply { description = "Se detectó el patrón de emergencia." },
        )
    }

    private fun buildOngoingNotification() =
        NotificationCompat.Builder(this, ONGOING_CHANNEL_ID)
            .setContentTitle("SIRE · Detección activa")
            .setContentText("Vigilando el botón de encendido para el SOS.")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

    private fun showAlertNotification() {
        val notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setContentTitle("🚨 Patrón SOS detectado")
            .setContentText(
                "Se detectaron $REQUIRED_TOGGLES pulsaciones del botón de encendido.",
            )
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        getSystemService(NotificationManager::class.java)
            .notify(ALERT_NOTIFICATION_ID, notification)
    }

    companion object {
        private const val ONGOING_CHANNEL_ID = "sire_sos_ongoing"
        private const val ALERT_CHANNEL_ID = "sire_sos_alert"
        private const val ONGOING_NOTIFICATION_ID = 1001
        private const val ALERT_NOTIFICATION_ID = 1002

        private const val EVENT_SOS = "sos_triggered"

        // Debe coincidir con AppConfig en Dart (sosButtonPresses / sosDetectionWindow).
        private const val REQUIRED_TOGGLES = 3
        private const val WINDOW_MS = 5000L
    }
}
