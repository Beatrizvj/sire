package gt.edu.miumg.sire

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.CountDownTimer
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat

/**
 * RF-13: pantalla de cuenta regresiva del SOS que aparece SOBRE la pantalla de
 * bloqueo. La lanza el full-screen intent de [PowerButtonService] al detectar
 * el patrón del botón de encendido. Con `setShowWhenLocked` + `setTurnScreenOn`
 * enciende y se muestra encima del bloqueo (en Samsung/One UI la notificación
 * sola no basta). Muestra el conteo y un botón grande "CANCELAR"; si no se
 * cancela, el servicio difunde el SOS. Esta pantalla es solo visual: el envío y
 * la cancelación reales los controla el servicio.
 */
class SosCountdownActivity : Activity() {

    private var timer: CountDownTimer? = null
    private var receiver: BroadcastReceiver? = null
    private lateinit var contadorTv: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        mostrarSobrePantallaBloqueada()

        val segundos = intent?.getIntExtra(EXTRA_SEGUNDOS, 8) ?: 8
        setContentView(construirUi(segundos))

        // Se cierra si el servicio resuelve el SOS (enviado o cancelado desde la
        // notificación), para no quedar colgada sobre el bloqueo.
        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                finish()
            }
        }
        ContextCompat.registerReceiver(
            this,
            receiver,
            IntentFilter(ACTION_SOS_RESUELTO),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )

        timer = object : CountDownTimer(segundos * 1000L, 1000L) {
            override fun onTick(ms: Long) {
                val s = ((ms + 999L) / 1000L).toInt()
                contadorTv.text = "Se enviará en $s s"
            }

            override fun onFinish() {
                contadorTv.text = "Enviando SOS…"
                finish()
            }
        }.start()
    }

    private fun mostrarSobrePantallaBloqueada() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun construirUi(segundos: Int): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#B71C1C"))
            setPadding(64, 64, 64, 64)
        }
        val titulo = TextView(this).apply {
            text = "🚨 SOS detectado"
            setTextColor(Color.WHITE)
            textSize = 30f
            gravity = Gravity.CENTER
        }
        contadorTv = TextView(this).apply {
            text = "Se enviará en $segundos s"
            setTextColor(Color.WHITE)
            textSize = 24f
            gravity = Gravity.CENTER
            setPadding(0, 48, 0, 24)
        }
        val sub = TextView(this).apply {
            text = "Toca CANCELAR si fue por error"
            setTextColor(Color.parseColor("#FFCDD2"))
            textSize = 16f
            gravity = Gravity.CENTER
        }
        val cancelar = Button(this).apply {
            text = "CANCELAR"
            textSize = 20f
            setPadding(0, 40, 0, 40)
            setOnClickListener {
                startService(
                    Intent(this@SosCountdownActivity, PowerButtonService::class.java)
                        .apply { action = ACTION_CANCEL_SOS },
                )
                finish()
            }
        }
        val botonParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        ).apply { topMargin = 64 }

        root.addView(titulo)
        root.addView(contadorTv)
        root.addView(sub)
        root.addView(cancelar, botonParams)
        return root
    }

    override fun onDestroy() {
        timer?.cancel()
        receiver?.let { runCatching { unregisterReceiver(it) } }
        super.onDestroy()
    }

    companion object {
        const val EXTRA_SEGUNDOS = "segundos"
        const val ACTION_CANCEL_SOS = "gt.edu.miumg.sire.CANCEL_SOS"
        const val ACTION_SOS_RESUELTO = "gt.edu.miumg.sire.SOS_RESUELTO"
    }
}
