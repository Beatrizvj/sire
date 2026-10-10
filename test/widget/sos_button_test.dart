import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sire/features/alerts/presentation/widgets/sos_button.dart';

/// El botón SOS es el núcleo del ciudadano: debe dispararse al tocarlo y
/// bloquearse (mostrando progreso) mientras se envía.
///
/// Nota: el botón tiene una animación en bucle, así que se usa `pump()` con
/// duración fija en lugar de `pumpAndSettle()` (que nunca terminaría).
void main() {
  testWidgets('muestra SOS y responde al toque cuando no está enviando',
      (tester) async {
    var toques = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SosButton(isSending: false, onPressed: () => toques++),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('SOS'), findsOneWidget);
    expect(find.byIcon(Icons.sos), findsOneWidget);

    await tester.tap(find.byType(SosButton));
    expect(toques, 1);
  });

  testWidgets('bloquea el toque y muestra progreso mientras envía',
      (tester) async {
    var toques = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SosButton(isSending: true, onPressed: () => toques++),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('SOS'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(SosButton), warnIfMissed: false);
    expect(toques, 0);
  });
}
