import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sire/features/alerts/presentation/widgets/sos_countdown_dialog.dart';

/// RF-13: antes de difundir un SOS del botón en pantalla hay una cuenta
/// regresiva para cancelar. Verifica las tres salidas: cancelar (no envía),
/// enviar ahora (envía) y agotar el tiempo (envía).
void main() {
  Future<void> abrirDialogo(WidgetTester tester,
      {required int segundos, required void Function(bool?) onResultado}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async =>
                  onResultado(await showSosCountdown(context, segundos: segundos)),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pump(); // inicia showDialog
    await tester.pump(const Duration(milliseconds: 300)); // termina la transición
  }

  testWidgets('CANCELAR no envía (devuelve false)', (tester) async {
    bool? resultado;
    await abrirDialogo(tester, segundos: 8, onResultado: (r) => resultado = r);

    expect(find.text('Enviando SOS…'), findsOneWidget);
    await tester.tap(find.text('CANCELAR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(resultado, isFalse);
  });

  testWidgets('"Enviar ahora" envía (devuelve true)', (tester) async {
    bool? resultado;
    await abrirDialogo(tester, segundos: 8, onResultado: (r) => resultado = r);

    await tester.tap(find.text('Enviar ahora'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(resultado, isTrue);
  });

  testWidgets('al agotarse el tiempo se envía (true)', (tester) async {
    bool? resultado;
    await abrirDialogo(tester, segundos: 2, onResultado: (r) => resultado = r);

    expect(find.text('Enviando SOS…'), findsOneWidget);
    // Avanza los 2 s de la cuenta regresiva.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(resultado, isTrue);
    expect(find.text('Enviando SOS…'), findsNothing);
  });
}
