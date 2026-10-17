import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sire/core/config/version_app.dart';

/// El aviso de versión nueva del panel compara contra este número: si no
/// coincide con pubspec.yaml, el panel avisaría siempre (o nunca).
void main() {
  test('kNumeroCompilacion coincide con el +N de pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(r'^version:\s*([\d.]+)\+(\d+)', multiLine: true)
        .firstMatch(pubspec);
    expect(m, isNotNull);
    expect(kVersionNombre, m!.group(1));
    expect(kNumeroCompilacion, int.parse(m.group(2)!));
  });
}
