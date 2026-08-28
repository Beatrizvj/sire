import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/app_providers.dart';

/// Preferencia de tema (claro / oscuro / automático) **persistida** con
/// SharedPreferences. La consume [SireApp] para el `themeMode` de la app, así
/// que aplica a ambos roles en el móvil. Por defecto sigue al sistema.
const _kThemeModeKey = 'sire_theme_mode';

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return _parse(prefs.getString(_kThemeModeKey));
  }

  /// Cambia y guarda la preferencia.
  Future<void> set(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kThemeModeKey, mode.name);
  }

  static ThemeMode _parse(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
