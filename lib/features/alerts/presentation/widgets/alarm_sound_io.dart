import 'package:audioplayers/audioplayers.dart';

// Implementación para móvil (Android/iOS): audioplayers funciona bien aquí.
final AudioPlayer _player = AudioPlayer(playerId: 'sire_alarm');

/// Sirena en bucle (alarma continua).
Future<void> alarmLoop() async {
  await _player.setReleaseMode(ReleaseMode.loop);
  await _player.stop();
  await _player.play(AssetSource('sounds/alerta.wav'));
}

/// Sirena una sola vez (prueba del botón "Activar sonido").
Future<void> alarmOnce() async {
  await _player.setReleaseMode(ReleaseMode.stop);
  await _player.stop();
  await _player.play(AssetSource('sounds/alerta.wav'));
}

/// Detiene la sirena.
Future<void> alarmStop() => _player.stop();
