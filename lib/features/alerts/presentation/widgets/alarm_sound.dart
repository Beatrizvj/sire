// Reproductor de la sirena de la alarma, con implementación por plataforma:
// - Web: usa el elemento <audio> nativo del navegador. (audioplayers lanza
//   MissingPluginException en la web de este proyecto, por eso no sonaba.)
// - Móvil: usa audioplayers, que ahí funciona bien.
// Ambas implementaciones exponen las mismas funciones:
//   alarmLoop()  · sirena en bucle
//   alarmOnce()  · sirena una vez
//   alarmStop()  · detener
export 'alarm_sound_io.dart' if (dart.library.html) 'alarm_sound_web.dart';
