import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sire/features/alerts/domain/entities/alert_status.dart';
import 'package:sire/features/alerts/domain/entities/sos_alert.dart';
import 'package:sire/features/alerts/domain/entities/sos_source.dart';
import 'package:sire/features/alerts/domain/usecases/trigger_sos.dart';

/// Ubicación en vivo: a dónde llevar a la autoridad y formato del id del SOS.
void main() {
  SosAlert alerta({double? latAct, double? lngAct, AlertStatus? estado}) =>
      SosAlert(
        id: 'x',
        latitude: 14.89,
        longitude: -91.60,
        timestamp: DateTime(2026, 10, 15, 8),
        source: SosSource.screenButton,
        status: estado ?? AlertStatus.pendiente,
        latitudActual: latAct,
        longitudActual: lngAct,
      );

  test('sin seguimiento, lleva a la ubicación del SOS', () {
    final a = alerta();
    expect(a.tieneUbicacionEnVivo, isFalse);
    expect(a.latitudParaLlegar, 14.89);
    expect(a.longitudParaLlegar, -91.60);
  });

  test('con seguimiento, lleva a donde está AHORA', () {
    final a = alerta(latAct: 14.90, lngAct: -91.61);
    expect(a.tieneUbicacionEnVivo, isTrue);
    expect(a.latitudParaLlegar, 14.90);
    expect(a.longitudParaLlegar, -91.61);
    // La ubicación original del SOS se conserva (mapa de calor, reportes).
    expect(a.latitude, 14.89);
  });

  test('solo sigue abierta si está pendiente o atendida', () {
    expect(alerta().sigueAbierta, isTrue);
    expect(alerta(estado: AlertStatus.atendida).sigueAbierta, isTrue);
    expect(alerta(estado: AlertStatus.resuelta).sigueAbierta, isFalse);
    expect(alerta(estado: AlertStatus.falsaAlarma).sigueAbierta, isFalse);
  });

  test('id del SOS legible y ordenable por fecha', () {
    final id = idDeAlerta(DateTime(2026, 7, 2, 6, 5, 9), azar: Random(1));
    expect(id, matches(RegExp(r'^20260702-060509-\d{4}$')));
  });

  test('antigüedad de la ubicación', () {
    final ahora = DateTime(2026, 10, 15, 8, 10);
    expect(haceCuanto(ahora.subtract(const Duration(seconds: 8)), ahora: ahora),
        'hace 8 s');
    expect(haceCuanto(ahora.subtract(const Duration(minutes: 3)), ahora: ahora),
        'hace 3 min');
  });
}
