package gt.edu.miumg.sire

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Reinicia la detección del botón de encendido tras reiniciar el teléfono.
 *
 * Solo arranca el servicio si el ciudadano tenía la detección ACTIVADA
 * (`KEY_ENABLED`). Si el sistema bloquea el arranque en frío por las
 * restricciones de servicios en primer plano, se ignora silenciosamente: el
 * usuario reactivará la detección al abrir la app.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_LOCKED_BOOT_COMPLETED
        ) {
            return
        }

        val prefs = context.getSharedPreferences(
            PowerButtonService.PREFS,
            Context.MODE_PRIVATE,
        )
        if (!prefs.getBoolean(PowerButtonService.KEY_ENABLED, false)) return

        val servicio = Intent(context, PowerButtonService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(servicio)
            } else {
                context.startService(servicio)
            }
            Log.i("SirePower", "Detección reiniciada tras el arranque del teléfono")
        } catch (e: Exception) {
            Log.w("SirePower", "No se pudo reiniciar la detección al arrancar: ${e.message}")
        }
    }
}
