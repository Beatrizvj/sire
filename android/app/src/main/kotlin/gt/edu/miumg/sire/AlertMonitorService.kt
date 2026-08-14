package gt.edu.miumg.sire

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.firestore.DocumentChange
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration

/**
 * Servicio en primer plano para las AUTORIDADES (COCODE / Municipalidad).
 *
 * Mientras la autoridad tiene la sesión iniciada, este servicio escucha la
 * colección `alertas` de Firestore y, cuando entra una alerta NUEVA, hace sonar
 * una sirena y muestra una notificación de emergencia — **aunque la app esté en
 * segundo plano**. No usa FCM ni backend: el propio servicio mantiene el
 * listener mientras vive (como el PowerButtonService, pero escuchando en vez de
 * emitir).
 *
 * Nota (MVP): por ahora suena por TODA alerta nueva pendiente. El filtro por
 * localidad (que un COCODE solo oiga su aldea) se agregará cuando la alerta
 * guarde la localidad del ciudadano.
 */
class AlertMonitorService : Service() {

    private var registration: ListenerRegistration? = null
    private val conocidas = HashSet<String>()
    private var primeraCarga = true
    private var player: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        createChannels()
        try {
            startForeground(ONGOING_ID, buildOngoingNotification())
        } catch (e: Exception) {
            Log.w(TAG, "No se pudo iniciar el FGS de monitoreo: ${e.message}")
            stopSelf()
            return
        }
        Log.i(TAG, "Monitoreo de alertas iniciado.")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_SILENCE) {
            stopSound()
        } else {
            // (Re)inicia la escucha con el filtro actual (por si cambió el grupo).
            reiniciarEscucha()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        registration?.remove()
        registration = null
        stopSound()
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    // --- Escucha en tiempo real de Firestore ---

    private fun reiniciarEscucha() {
        registration?.remove()
        conocidas.clear()
        primeraCarga = true

        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val todos = prefs.getBoolean(KEY_TODOS, true)
        val contactos =
            prefs.getStringSet(KEY_CONTACTOS, emptySet())?.toList() ?: emptyList()
        val base = FirebaseFirestore.getInstance().collection("alertas")
        // AUTORIDAD: escucha TODAS las alertas. CONTACTO DE CONFIANZA (ciudadano):
        // solo las de los uids que la autoridad le asignó (whereIn, máx. 10) —
        // justo lo que las reglas de Firestore le permiten leer (RF-11).
        val query = when {
            todos -> base
            contactos.isNotEmpty() -> base.whereIn("idUsuario", contactos.take(10))
            else -> null
        }
        if (query == null) {
            Log.w(TAG, "Monitoreo sin filtro válido; no se escucha.")
            return
        }
        registration = query
            .addSnapshotListener { snapshot, error ->
                if (error != null || snapshot == null) {
                    if (error != null) Log.w(TAG, "Listener: ${error.message}")
                    return@addSnapshotListener
                }
                for (change in snapshot.documentChanges) {
                    if (change.type != DocumentChange.Type.ADDED) continue
                    val doc = change.document
                    val id = doc.id
                    // Primera emisión: registrar lo existente SIN sonar.
                    if (primeraCarga) {
                        conocidas.add(id)
                        continue
                    }
                    if (conocidas.contains(id)) continue
                    conocidas.add(id)
                    val estado = doc.getString("estado") ?: "pendiente"
                    if (estado != "pendiente") continue
                    val nombre = doc.getString("nombreUsuario")?.takeIf { it.isNotBlank() }
                        ?: "Ciudadano"
                    onNuevaAlerta(nombre, doc.getString("direccion"))
                }
                primeraCarga = false
            }
    }

    private fun onNuevaAlerta(nombre: String, direccion: String?) {
        showAlertNotification(nombre, direccion)
        playSiren()
    }

    // --- Sirena (canal de alarma, suena aunque el timbre esté bajo) ---

    private fun playSiren() {
        stopSound()
        val mp = MediaPlayer.create(this, R.raw.sire_alerta) ?: return
        mp.isLooping = true
        mp.setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        player = mp
        runCatching { mp.start() }
        // Freno de seguridad: la sirena no suena más de 25 s aunque no la silencien.
        handler.postDelayed({ stopSound() }, 25_000L)
    }

    private fun stopSound() {
        player?.let { p ->
            runCatching {
                if (p.isPlaying) p.stop()
                p.release()
            }
        }
        player = null
    }

    // --- Notificaciones ---

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                ONGOING_CHANNEL,
                "Monitoreo de alertas",
                NotificationManager.IMPORTANCE_LOW,
            ).apply { description = "Escucha alertas SOS para las autoridades." },
        )
        manager.createNotificationChannel(
            NotificationChannel(
                ALERT_CHANNEL,
                "Alerta SOS entrante",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Suena cuando entra una alerta nueva."
                // El sonido lo maneja el MediaPlayer (stream de alarma); el canal
                // no reproduce sonido propio para no solaparse.
                setSound(null, null)
            },
        )
    }

    private fun buildOngoingNotification() =
        NotificationCompat.Builder(this, ONGOING_CHANNEL)
            .setContentTitle("SIRE · Monitoreo activo")
            .setContentText("Escuchando alertas de la comunidad.")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

    private fun showAlertNotification(nombre: String, direccion: String?) {
        val abrir = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val abrirPI = PendingIntent.getActivity(
            this,
            0,
            abrir ?: Intent(),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val silenciarPI = PendingIntent.getService(
            this,
            1,
            Intent(this, AlertMonitorService::class.java).apply { action = ACTION_SILENCE },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val texto = direccion?.takeIf { it.isNotBlank() } ?: "Toca para atender en SIRE."
        val notif = NotificationCompat.Builder(this, ALERT_CHANNEL)
            .setContentTitle("🚨 Nueva alerta de $nombre")
            .setContentText(texto)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(abrirPI)
            .setFullScreenIntent(abrirPI, true)
            .addAction(0, "Silenciar", silenciarPI)
            .build()
        getSystemService(NotificationManager::class.java).notify(ALERT_ID, notif)
    }

    companion object {
        private const val TAG = "SireMonitor"
        private const val ONGOING_CHANNEL = "sire_monitor_ongoing"
        private const val ALERT_CHANNEL = "sire_monitor_alert"
        private const val ONGOING_ID = 2001
        private const val ALERT_ID = 2002
        const val ACTION_SILENCE = "gt.edu.miumg.sire.SILENCE"

        // RF-11: filtro del monitoreo (lo escribe MainActivity al iniciar).
        // todos=true → autoridad (todas las alertas); false → ciudadano contacto
        // de confianza, que solo oye las alertas de los uids en `contactos`.
        const val PREFS = "sire_monitor"
        const val KEY_TODOS = "todos"
        const val KEY_CONTACTOS = "contactos"
    }
}
