import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Instancia de SharedPreferences. Se sobreescribe en `main()` con la real
/// (`overrideWithValue`) porque su creación es asíncrona.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider debe sobreescribirse en main().',
  ),
);
