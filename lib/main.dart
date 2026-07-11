import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/di/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase queda desactivado hasta el Hito 3 (ver docs/CONNECT_FIREBASE.md).
  // Tras `flutterfire configure`, usar:
  //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (AppConfig.firebaseEnabled) {
    await Firebase.initializeApp();
  }

  // SharedPreferences se crea de forma asíncrona y se inyecta vía override.
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const SireApp(),
    ),
  );
}
