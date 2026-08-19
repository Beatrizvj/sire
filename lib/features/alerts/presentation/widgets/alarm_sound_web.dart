// Implementación para WEB: usa el elemento <audio> nativo del navegador.
// Se evita audioplayers porque en la web de este proyecto lanza
// MissingPluginException (su parte web no queda registrada). El <audio> nativo
// sí reproduce el .wav (verificado en el navegador: play OK).
// El asset se sirve en `assets/assets/sounds/alerta.wav` en el build web.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

final html.AudioElement _audio =
    html.AudioElement('assets/assets/sounds/alerta.wav')..preload = 'auto';

/// Sirena en bucle (alarma continua).
Future<void> alarmLoop() async {
  _audio.loop = true;
  _audio.currentTime = 0;
  await _audio.play();
}

/// Sirena una sola vez (prueba del botón "Activar sonido").
Future<void> alarmOnce() async {
  _audio.loop = false;
  _audio.currentTime = 0;
  await _audio.play();
}

/// Detiene la sirena.
Future<void> alarmStop() async {
  _audio.pause();
  _audio.currentTime = 0;
}
