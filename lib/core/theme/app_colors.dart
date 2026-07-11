import 'package:flutter/material.dart';

/// Paleta de SIRE. El color semilla (rojo emergencia) genera todo el
/// [ColorScheme] Material 3 en [AppTheme].
class AppColors {
  AppColors._();

  /// Rojo emergencia: identidad visual y color del botón SOS.
  static const Color emergency = Color(0xFFC62828);
  static const Color emergencyDark = Color(0xFF8E0000);

  /// Verde "estado seguro / resuelto".
  static const Color safe = Color(0xFF2E7D32);

  /// Ámbar "pendiente / advertencia".
  static const Color warning = Color(0xFFF9A825);

  /// Semilla para ColorScheme.fromSeed.
  static const Color seed = emergency;
}
