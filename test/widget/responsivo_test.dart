import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sire/features/alerts/domain/entities/alert_status.dart';
import 'package:sire/features/alerts/domain/entities/sos_alert.dart';
import 'package:sire/features/alerts/domain/entities/sos_source.dart';
import 'package:sire/features/alerts/presentation/widgets/alert_tile.dart';
import 'package:sire/features/alerts/presentation/widgets/sos_button.dart';
import 'package:sire/features/alerts/presentation/widgets/sos_countdown_dialog.dart';
import 'package:sire/features/alerts/presentation/widgets/ubicacion_en_vivo.dart';
import 'package:sire/features/auth/presentation/pages/login_page.dart';
import 'package:sire/features/auth/presentation/providers/auth_providers.dart';

import '../widget_test.dart' show FakeAuthRepository;

/// Responsivo de la app móvil: las pantallas y componentes clave se dibujan sin
/// desbordarse en teléfonos pequeños, medianos y tablets, con letra normal y
/// con letra grande (accesibilidad). Un desborde de Flutter hace fallar la
/// prueba.
void main() {
  const tamanos = <String, Size>{
    'teléfono pequeño 320×568': Size(320, 568),
    'teléfono 360×740': Size(360, 740),
    'teléfono grande 412×915': Size(412, 915),
    'tablet 800×1280': Size(800, 1280),
  };
  const escalas = [1.0, 1.3];

  final alertaLarga = SosAlert(
    id: '20261016-154052-1234',
    latitude: 14.89592,
    longitude: -91.61542,
    accuracy: 28,
    timestamp: DateTime(2026, 10, 16, 15, 40, 52),
    source: SosSource.powerButton,
    status: AlertStatus.atendida,
    address: 'V9WM+8XF, San Miguel Sigüilá, Guatemala, San Miguel Sigüilá, '
        'Quetzaltenango, Guatemala',
    categoria: 'Persona sospechosa',
    atendidaEn: DateTime(2026, 10, 16, 15, 52),
    latitudActual: 14.8961,
    longitudActual: -91.6150,
    precisionActual: 9,
    ubicacionActualEn: DateTime.now(),
  );

  Future<void> dibujar(WidgetTester tester, Size tam, double escala, Widget w) async {
    await tester.binding.setSurfaceSize(tam);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: w,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final t in tamanos.entries) {
    for (final e in escalas) {
      final caso = '${t.key} · letra ×$e';

      testWidgets('Inicio de sesión sin desbordes ($caso)', (tester) async {
        await dibujar(tester, t.value, e, const LoginPage());
        expect(tester.takeException(), isNull);
      });

      testWidgets('Botón SOS e historial sin desbordes ($caso)', (tester) async {
        await dibujar(
          tester,
          t.value,
          e,
          Scaffold(
            body: ListView(children: [
              Center(child: SosButton(onPressed: () {}, isSending: false)),
              AlertTile(alert: alertaLarga, onTap: () {}),
              Padding(
                padding: const EdgeInsets.all(16),
                child: IndicadorEnVivo(alerta: alertaLarga),
              ),
            ]),
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('Cuenta regresiva sin desbordes ($caso)', (tester) async {
        await dibujar(
          tester,
          t.value,
          e,
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showSosCountdown(context, segundos: 8),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('abrir'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        // Se cierra para no dejar el temporizador activo.
        await tester.tap(find.text('CANCELAR'));
        await tester.pump(const Duration(milliseconds: 400));
      });
    }
  }
}
