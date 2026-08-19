package gt.edu.miumg.sire

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

/**
 * Servicio en primer plano que detecta el patrón de emergencia de SIRE
 * (3 pulsaciones del botón de encendido) y **envía el SOS de forma nativa**.
 *
 * A diferencia de la v1, ya NO depende de Flutter para guardar la alerta:
 * el propio servicio captura el GPS y escribe en Firestore. Así el SOS
 * funciona aunque la pantalla esté apagada o la app esté en segundo plano
 * (cuando el motor de Flutter está suspendido).
 *
 *  - WAKE_LOCK: mantiene el CPU despierto para captar las pulsaciones al
 *    primer intento (evita que Doze pierda los eventos de pantalla).
 *  - LocationManager: captura la ubicación sin depender de Flutter.
 *  - FirebaseFirestore: guarda la alerta directamente en la colección `alertas`.
 */
class PowerButtonService : Service() {

    // Detección de las 3 pulsaciones: ventana fija desde el Clic 1 + anti-rebote.
    private var contador = 0
    private var tAnterior = 0L
    private val handler = Handler(Looper.getMainLooper())
    private val resetRunnable = Runnable {
        Log.d(TAG, "ventana expiró sin llegar a 3 → reset")
        reset()
    }
    private var vibrator: Vibrator? = null

    // RF-13: cuenta regresiva de cancelación antes de difundir. `sosPendiente` es
    // true mientras corre; el tick baja `segundosRestantes`, actualiza la
    // notificación cada segundo y, al llegar a 0, difunde la alerta.
    private var sosPendiente = false
    private var segundosRestantes = 0

    private val cuentaRegresiva = object : Runnable {
        override fun run() {
            if (segundosRestantes <= 0) {
                sosPendiente = false
                showAlertNotification() // reemplaza la cuenta regresiva por "Enviando…"
                captureLocationAndSave()
                return
            }
            showCountdownNotification(segundosRestantes)
            segundosRestantes--
            handler.postDelayed(this, 1000)
        }
    }

    private var screenReceiver: BroadcastReceiver? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val ioExecutor = Executors.newSingleThreadExecutor()

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        // Defensa: en Android 14+ arrancar un FGS de tipo "location" sin el
        // permiso de ubicación lanza SecurityException. Si eso ocurre, NO se
        // debe tumbar la app: se detiene el servicio limpiamente. La capa
        // Flutter ya exige el permiso antes de iniciar, así que esto es respaldo.
        try {
            startForeground(ONGOING_NOTIFICATION_ID, buildOngoingNotification())
        } catch (e: Exception) {
            stopSelf()
            return
        }
        acquireWakeLock()
        registerScreenReceiver()
        vibrator = obtenerVibrador()
        isRunning = true
        Log.i(TAG, "Servicio iniciado · ventana=${WINDOW_MS}ms · antirebote=${MIN_GAP_MS}ms")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // RF-13: el usuario tocó "Cancelar" en la notificación de cuenta regresiva.
        if (intent?.action == ACTION_CANCEL_SOS) {
            cancelPendingSos()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        handler.removeCallbacksAndMessages(null)
        screenReceiver?.let { receiver -> runCatching { unregisterReceiver(receiver) } }
        screenReceiver = null
        wakeLock?.let { if (it.isHeld) runCatching { it.release() } }
        wakeLock = null
        ioExecutor.shutdown()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // --- Fiabilidad: CPU despierto mientras se vigila el botón ---

    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "sire:power_button").apply {
            setReferenceCounted(false)
            runCatching { acquire() }
        }
    }

    // --- Detección del patrón (alternancias de pantalla) ---

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

    /**
     * Cada SCREEN_ON/SCREEN_OFF equivale a UNA pulsación (Android no permite leer
     * la tecla de encendido directo). Lógica anti-hostigo:
     *  - Anti-rebote: ignora ecos del hardware (< MIN_GAP_MS del clic anterior).
     *  - Clics 1 y 2: SILENCIO (no molestar en el uso normal del botón).
     *  - Clic 3: UNA vibración clara + dispara el SOS.
     *  - Si la ventana expira sin llegar a 3: se limpia el contador.
     */
    private fun onScreenToggle() {
        val ahora = System.currentTimeMillis()
        if (ahora - tAnterior < MIN_GAP_MS) {
            Log.d(TAG, "rebote ignorado (${ahora - tAnterior}ms del anterior)")
            return
        }
        tAnterior = ahora
        contador++
        Log.d(TAG, "pulsación aceptada · contador=$contador/$REQUIRED_TOGGLES")

        when {
            contador == 1 -> {
                handler.removeCallbacks(resetRunnable)
                handler.postDelayed(resetRunnable, WINDOW_MS) // sin vibración
            }
            contador >= REQUIRED_TOGGLES -> {
                reset()
                Log.i(TAG, "¡3 pulsaciones detectadas! → disparando SOS")
                vibrar(longArrayOf(0, 300)) // una sola vibración clara = SOS enviado
                onPatternDetected()
            }
        }
    }

    /** Limpia el contador y cancela la ventana. NO toca [tAnterior], para que el
     * asentamiento de la pantalla tras el 3er clic siga filtrado por el anti-rebote. */
    private fun reset() {
        contador = 0
        handler.removeCallbacks(resetRunnable)
    }

    private fun obtenerVibrador(): Vibrator? = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager)
                .defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    } catch (e: Exception) {
        null
    }

    private fun vibrar(patron: LongArray) {
        val v = vibrator ?: return
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                v.vibrate(VibrationEffect.createWaveform(patron, -1))
            } else {
                @Suppress("DEPRECATION")
                v.vibrate(patron, -1)
            }
        }
    }

    /**
     * RF-13: al detectar el patrón NO se difunde de inmediato. Se abre una
     * ventana de [CANCEL_WINDOW_SECONDS] segundos con una notificación de cuenta
     * regresiva y acción "Cancelar"; si el usuario no la cancela, la alerta se
     * envía. Así se previenen falsos positivos por una pulsación accidental, a
     * costa de unos pocos segundos.
     */
    private fun onPatternDetected() {
        handler.removeCallbacks(cuentaRegresiva) // por si hubiera una en curso
        sosPendiente = true
        segundosRestantes = CANCEL_WINDOW_SECONDS
        handler.post(cuentaRegresiva) // primer tick inmediato (muestra la notificación)
    }

    /** Cancela el envío pendiente (RF-13) y retira la notificación de cuenta regresiva. */
    private fun cancelPendingSos() {
        val habia = sosPendiente
        handler.removeCallbacks(cuentaRegresiva)
        sosPendiente = false
        segundosRestantes = 0
        getSystemService(NotificationManager::class.java).cancel(ALERT_NOTIFICATION_ID)
        if (habia) {
            vibrar(longArrayOf(0, 80, 80, 80)) // vibración breve = SOS cancelado
            Log.i(TAG, "SOS cancelado por el usuario dentro de la ventana")
        }
    }

    /** Notificación con acción "Cancelar" durante la ventana previa al envío (RF-13). */
    private fun showCountdownNotification(segundos: Int) {
        val cancelIntent = Intent(this, PowerButtonService::class.java).apply {
            action = ACTION_CANCEL_SOS
        }
        val cancelPending = PendingIntent.getService(
            this,
            0,
            cancelIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setContentTitle("SOS detectado")
            .setContentText("Se enviará en $segundos s. Toca CANCELAR si fue un error.")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true) // solo vibra/heads-up al inicio; los ticks, silenciosos
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Cancelar",
                cancelPending,
            )
            .build()
        getSystemService(NotificationManager::class.java)
            .notify(ALERT_NOTIFICATION_ID, notification)
    }

    // --- SOS nativo: captura GPS y guarda en Firestore ---

    private fun captureLocationAndSave() {
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val provider = when {
            lm.isProviderEnabled(LocationManager.GPS_PROVIDER) -> LocationManager.GPS_PROVIDER
            lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) -> LocationManager.NETWORK_PROVIDER
            else -> null
        }
        try {
            if (provider != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Solicita una posición fresca (mejor para un SOS) fuera del hilo principal.
                lm.getCurrentLocation(provider, null, ioExecutor) { location ->
                    saveAlert(location ?: lastKnown(lm))
                }
            } else {
                val loc = provider?.let { lm.getLastKnownLocation(it) } ?: lastKnown(lm)
                ioExecutor.execute { saveAlert(loc) }
            }
        } catch (e: SecurityException) {
            ioExecutor.execute { saveAlert(null) }
        }
    }

    private fun lastKnown(lm: LocationManager): Location? = try {
        lm.getLastKnownLocation(LocationManager.GPS_PROVIDER)
            ?: lm.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
    } catch (e: SecurityException) {
        null
    }

    private fun saveAlert(location: Location?) {
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        // Usa el usuario AUTENTICADO EN VIVO, no el guardado en prefs (que puede
        // quedar viejo al cambiar de cuenta). Así idUsuario == request.auth.uid y
        // la regla de Firestore acepta la escritura, sin importar de quién sea la
        // sesión actual. (Prefs solo como respaldo.)
        val authUser = FirebaseAuth.getInstance().currentUser
        val uid = authUser?.uid ?: prefs.getString(KEY_UID, "") ?: ""
        val nombre = authUser?.displayName?.takeIf { it.isNotBlank() }
            ?: prefs.getString(KEY_NOMBRE, "") ?: ""
        val data = hashMapOf<String, Any?>(
            "idUsuario" to uid,
            "nombreUsuario" to nombre,
            "fecha" to Timestamp(Date()),
            "estado" to "pendiente",
            "tipo" to "SOS",
            "origen" to "powerButton",
            "creadoEn" to FieldValue.serverTimestamp(),
        )
        if (location != null) {
            data["latitud"] = location.latitude
            data["longitud"] = location.longitude
            data["precision"] = location.accuracy.toDouble()
        }
        val doc = FirebaseFirestore.getInstance().collection("alertas").document(buildDocId())
        runCatching {
            // Se ESCRIBE de inmediato, SIN esperar la dirección, para que la alerta
            // llegue al panel (y suene) cuanto antes. La dirección se resuelve
            // después y se agrega con un update; mientras tanto el panel ya muestra
            // las coordenadas. Esto recorta el retraso del reverse geocoding.
            doc.set(data)
                .addOnSuccessListener {
                    // Solo se avisa "enviado" si de verdad se guardó (antes se
                    // avisaba aunque fallara, por eso parecía enviado sin llegar).
                    PowerButtonEvents.emit(EVENT_SOS)
                    if (location != null) {
                        runCatching {
                            ioExecutor.execute {
                                reverseGeocode(location.latitude, location.longitude)?.let { dir ->
                                    runCatching { doc.update("direccion", dir) }
                                }
                            }
                        }
                    }
                }
                .addOnFailureListener { e ->
                    Log.e(TAG, "No se pudo guardar el SOS del boton fisico", e)
                }
        }
    }

    // ID legible y ordenable por fecha: p. ej. 20260722-065701-3f2a.
    private fun buildDocId(): String {
        val stamp = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())
        val suffix = (1000..9999).random()
        return "$stamp-$suffix"
    }

    private fun reverseGeocode(lat: Double, lng: Double): String? = try {
        @Suppress("DEPRECATION")
        Geocoder(this, Locale.getDefault()).getFromLocation(lat, lng, 1)
            ?.firstOrNull()?.getAddressLine(0)
    } catch (e: Exception) {
        null
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
        // Canal de alertas HIGH y VISIBLE EN LA PANTALLA DE BLOQUEO, para que el
        // aviso "SOS detectado · CANCELAR" aparezca sin necesidad de desbloquear.
        runCatching { manager.deleteNotificationChannel(ALERT_CHANNEL_ID_OLD) }
        manager.createNotificationChannel(
            NotificationChannel(
                ALERT_CHANNEL_ID,
                "Alertas SOS",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Se detectó el patrón de emergencia."
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            },
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
            .setContentText("Enviando tu ubicación de emergencia…")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .build()
        getSystemService(NotificationManager::class.java)
            .notify(ALERT_NOTIFICATION_ID, notification)
    }

    companion object {
        private const val TAG = "SirePower"

        /** true mientras el servicio de detección está vivo. Permite que el switch
         * de la app refleje el estado REAL (se actualiza en onCreate/onDestroy). */
        @Volatile
        var isRunning = false

        private const val ONGOING_CHANNEL_ID = "sire_sos_ongoing"
        // Canal nuevo (ID distinto) para forzar la config de visibilidad en
        // pantalla de bloqueo: Android no aplica cambios a un canal ya creado.
        private const val ALERT_CHANNEL_ID = "sire_sos_alerta"
        private const val ALERT_CHANNEL_ID_OLD = "sire_sos_alert"
        private const val ONGOING_NOTIFICATION_ID = 1001
        private const val ALERT_NOTIFICATION_ID = 1002

        private const val EVENT_SOS = "sos_triggered"

        // RF-13: acción de la notificación para cancelar el envío y duración de la
        // ventana de cancelación (pocos segundos antes de difundir la alerta).
        private const val ACTION_CANCEL_SOS = "gt.edu.miumg.sire.CANCEL_SOS"
        private const val CANCEL_WINDOW_SECONDS = 8

        // SharedPreferences compartido con MainActivity (uid del usuario en sesión).
        const val PREFS = "sire_native"
        const val KEY_UID = "uid"
        const val KEY_NOMBRE = "nombre"

        // Debe coincidir con AppConfig en Dart (sosButtonPresses / sosDetectionWindow).
        private const val REQUIRED_TOGGLES = 3

        // Ventana fija desde el Clic 1 para completar las 3 pulsaciones.
        // 4 s: da holgura al ritmo real de pulsación (2 s resultó muy justo).
        private const val WINDOW_MS = 4000L

        // Anti-rebote: ignora eventos de pantalla a < 300 ms del anterior
        // (ecos del hardware que en algunos Samsung inflaban el conteo).
        private const val MIN_GAP_MS = 300L
    }
}
