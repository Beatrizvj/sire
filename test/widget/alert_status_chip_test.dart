import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sire/features/alerts/domain/entities/alert_status.dart';
import 'package:sire/features/alerts/presentation/widgets/alert_status_chip.dart';

/// El chip de estado es la fuente visual única del estado de una alerta en la
/// app y el panel: debe mostrar siempre la etiqueta correcta.
void main() {
  Future<void> pump(WidgetTester tester, AlertStatus status) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: AlertStatusChip(status: status))),
        ),
      );

  testWidgets('muestra la etiqueta "Pendiente"', (tester) async {
    await pump(tester, AlertStatus.pendiente);
    expect(find.text('Pendiente'), findsOneWidget);
  });

  testWidgets('cambia la etiqueta según el estado', (tester) async {
    await pump(tester, AlertStatus.resuelta);
    expect(find.text('Resuelta'), findsOneWidget);

    await pump(tester, AlertStatus.falsaAlarma);
    expect(find.text('Falsa alarma'), findsOneWidget);
  });
}
