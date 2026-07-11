/// Configuración global y "feature flags" del proyecto SIRE.
///
/// Los flags permiten dejar la estructura lista para hitos posteriores
/// (Firebase, WhatsApp, mapas) sin que el primer build dependa de ellos.
class AppConfig {
  AppConfig._();

  static const String appName = 'SIRE';
  static const String appTagline =
      'Sistema Integral de Respuesta ante Emergencias';

  // --- Patrón del botón de encendido (núcleo de SIRE) ---
  /// Número de pulsaciones necesarias para disparar el SOS.
  static const int sosButtonPresses = 3;

  /// Ventana de tiempo dentro de la cual deben ocurrir las pulsaciones.
  static const Duration sosDetectionWindow = Duration(seconds: 5);

  // --- Feature flags (se activan en hitos posteriores) ---
  /// Hito 3: al conectar Firebase, cambiar a `true`.
  ///
  /// Es un getter (no `const`) a propósito: permite el patrón de repositorios
  /// local ↔ Firebase sin que el analizador marque las ramas de Firebase como
  /// código muerto mientras el valor es `false`.
  static bool get firebaseEnabled => false;

  /// Hito 6: mensajería por WhatsApp vía Cloud Functions.
  static bool get whatsappEnabled => false;
}
