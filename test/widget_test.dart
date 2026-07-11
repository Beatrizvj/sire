// Prueba de humo: verifica que la app arranca y muestra la pantalla SOS.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sire/app.dart';
import 'package:sire/core/di/app_providers.dart';

void main() {
  testWidgets('La app arranca y muestra la pantalla SOS', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const SireApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MaterialApp), findsOneWidget);
    // El texto "SOS" aparece en el botón y en la barra de navegación.
    expect(find.text('SOS'), findsWidgets);
  });
}
