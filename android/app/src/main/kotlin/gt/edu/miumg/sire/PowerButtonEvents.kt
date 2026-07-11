package gt.edu.miumg.sire

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * Puente de eventos entre [PowerButtonService] (que corre en segundo plano) y
 * Flutter. Mantiene el [EventChannel.EventSink] mientras la UI está escuchando
 * y publica los eventos en el hilo principal.
 *
 * Si la UI no está activa (sink == null) el evento se descarta; en ese caso el
 * propio servicio muestra una notificación como respaldo.
 */
object PowerButtonEvents {
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    var sink: EventChannel.EventSink? = null

    fun emit(event: String) {
        val current = sink ?: return
        mainHandler.post { current.success(event) }
    }
}
