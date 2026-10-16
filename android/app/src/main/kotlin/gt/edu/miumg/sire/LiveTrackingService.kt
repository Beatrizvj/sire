package gt.edu.miumg.sire

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration

/**
 * Seguimiento EN VIVO de la ubicación del ciudadano mientras su alerta SOS
 * sigue abierta.
 *
 * Tras enviar un SOS (botón en pantalla o botón de encendido), este servicio en
 * primer plano manda la posición del teléfono cada [INTERVALO_MS] a la alerta
 * (`alertas/{id}`: `latitudActual`, `longitudActual`, `precisionActual`,
 * `ubicacionActualEn`). Así la autoridad ve el punto moverse y "Cómo llegar" la
 * lleva a donde la persona está AHORA, no a donde estaba al enviar el SOS.
 *
 * Funciona con la app cerrada o la pantalla apagada (permiso de ubicación "todo
 * el tiempo"). Se detiene solo cuando la alerta pasa a Resuelta o Falsa alarma,
 * si se borra, o al cumplir [DURACION_MAX_MS], para no gastar batería ni seguir
 * a nadie más de lo necesario. Android muestra una notificación fija mientras
 * comparte la ubicación (transparencia para el ciudadano).
 */
class LiveTrackingService : Service() {

    private lateinit var fused: FusedLocationProviderClient
    private var alertaId: String? = null
    private var escuchaAlerta: ListenerRegistration? = null
    private val handler = Handler(Looper.getMainLooper())
    private val detenerPorTiempo = Runnable { detener("tiempo máximo alcanzado") }

    private val callback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            result.lastLocation?.let { enviar(it) }
        }
    }

    override fun onCreate() {
        super.onCreate()
        fused = LocationServices.getFusedLocationProviderClient(this)
        crearCanal()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            detener("detenido por la app")
            return START_NOT_STICKY
        }
        val id = intent?.getStringExtra(EXTRA_ALERTA_ID)
            ?: getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY_ALERTA, null)
        if (id.isNullOrBlank()) {
            stopSelf()
            return START_NOT_STICKY
        }
        // Se recuerda la alerta por si Android reinicia el servicio.
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString(KEY_ALERTA, id).apply()

        try {
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                notificacion(),
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION else 0,
            )
        } catch (e: Exception) {
            // Sin permiso de ubicación Android no deja iniciar el servicio.
            Log.w(TAG, "No se pudo iniciar el seguimiento: ${e.message}")
            stopSelf()
            return START_NOT_STICKY
        }

        if (id != alertaId) {
            alertaId = id
            iniciarSeguimiento(id)
        }
        return START_REDELIVER_INTENT
    }

    private fun iniciarSeguimiento(id: String) {
        val solicitud = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, INTERVALO_MS)
            .setMinUpdateIntervalMillis(INTERVALO_MIN_MS)
            .setMinUpdateDistanceMeters(DISTANCIA_MIN_M)
            .build()
        try {
            fused.requestLocationUpdates(solicitud, callback, Looper.getMainLooper())
        } catch (e: SecurityException) {
            detener("sin permiso de ubicación")
            return
        }

        // Se detiene en cuanto la autoridad cierra la alerta.
        escuchaAlerta?.remove()
        escuchaAlerta = FirebaseFirestore.getInstance().collection("alertas").document(id)
            .addSnapshotListener { snap, _ ->
                if (snap == null) return@addSnapshotListener
                val estado = snap.getString("estado")
                if (!snap.exists() || estado == "resuelta" || estado == "falsa_alarma") {
                    detener("alerta cerrada ($estado)")
                }
            }

        handler.removeCallbacks(detenerPorTiempo)
        handler.postDelayed(detenerPorTiempo, DURACION_MAX_MS)
    }

    private fun enviar(loc: Location) {
        val id = alertaId ?: return
        FirebaseFirestore.getInstance().collection("alertas").document(id)
            .update(
                mapOf(
                    "latitudActual" to loc.latitude,
                    "longitudActual" to loc.longitude,
                    "precisionActual" to loc.accuracy.toDouble(),
                    "ubicacionActualEn" to FieldValue.serverTimestamp(),
                ),
            )
            .addOnFailureListener { e ->
                // Sin señal Firestore guarda en cola y reintenta solo; un rechazo
                // de permisos significa que la alerta ya se cerró.
                Log.w(TAG, "No se pudo enviar la ubicación en vivo: ${e.message}")
            }
    }

    private fun detener(motivo: String) {
        Log.i(TAG, "Seguimiento en vivo detenido: $motivo")
        runCatching { fused.removeLocationUpdates(callback) }
        escuchaAlerta?.remove()
        escuchaAlerta = null
        handler.removeCallbacks(detenerPorTiempo)
        alertaId = null
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().remove(KEY_ALERTA).apply()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        runCatching { fused.removeLocationUpdates(callback) }
        escuchaAlerta?.remove()
        handler.removeCallbacks(detenerPorTiempo)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun crearCanal() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Ubicación en vivo",
                NotificationManager.IMPORTANCE_LOW,
            ).apply { description = "Comparte tu ubicación mientras tu SOS está abierto." },
        )
    }

    private fun notificacion() =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SIRE · Compartiendo tu ubicación")
            .setContentText("Las autoridades ven tu ubicación en vivo hasta que se cierre tu alerta.")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

    companion object {
        private const val TAG = "LiveTracking"
        private const val CHANNEL_ID = "sire_ubicacion_vivo"
        private const val NOTIFICATION_ID = 4311
        private const val PREFS = "sire_seguimiento"
        private const val KEY_ALERTA = "alerta_id"
        const val EXTRA_ALERTA_ID = "alertaId"
        const val ACTION_STOP = "gt.edu.miumg.sire.DETENER_SEGUIMIENTO"

        private const val INTERVALO_MS = 10_000L
        private const val INTERVALO_MIN_MS = 5_000L
        private const val DISTANCIA_MIN_M = 5f
        private const val DURACION_MAX_MS = 2 * 60 * 60 * 1000L

        /** Inicia (o cambia a) el seguimiento de la alerta [alertaId]. */
        fun iniciar(context: Context, alertaId: String) {
            val intent = Intent(context, LiveTrackingService::class.java)
                .putExtra(EXTRA_ALERTA_ID, alertaId)
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            }.onFailure { Log.w(TAG, "No se pudo iniciar el seguimiento: ${it.message}") }
        }

        fun detener(context: Context) {
            runCatching {
                context.startService(
                    Intent(context, LiveTrackingService::class.java).setAction(ACTION_STOP),
                )
            }
        }
    }
}
