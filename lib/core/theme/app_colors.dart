import 'package:flutter/material.dart';

/// Paleta de SIRE. El color semilla (rojo emergencia) genera todo el
/// [ColorScheme] Material 3 en [AppTheme].
class AppColors {
  AppColors._();

  /// Rojo emergencia: identidad visual y color del botón SOS.
  static const Color emergency = Color(0xFFC62828);
  static const Color emergencyDark = Color(0xFF8E0000);

  /// Fondo neutro institucional de la app (evita el tinte rosado del tema).
  static const Color neutralBgLight = Color(0xFFECEEF1);
  static const Color neutralBgDark = Color(0xFF16181B);

  /// Verde "estado seguro / resuelto".
  static const Color safe = Color(0xFF2E7D32);

  /// Ámbar "pendiente / advertencia".
  static const Color warning = Color(0xFFF9A825);

  /// Semilla para ColorScheme.fromSeed.
  static const Color seed = emergency;

  // ── Estados de alerta ──────────────────────────────────────────────
  // Paleta ÚNICA de los estados de una alerta. La usan tanto la app móvil
  // (Bandeja e historial) como el panel web, para que los colores coincidan
  // siempre en los dos. Cambiar aquí = cambiar en ambos lados a la vez.
  static const Color statusPendiente = warning; // ámbar — sin atender
  static const Color statusAtendida = Color(0xFF1565C0); // azul — en proceso
  static const Color statusResuelta = safe; // verde — resuelta
  static const Color statusFalsaAlarma = Color(0xFF616161); // gris — descartada
}
