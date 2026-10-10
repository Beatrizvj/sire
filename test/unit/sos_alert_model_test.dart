import 'package:flutter_test/flutter_test.dart';
import 'package:sire/features/alerts/data/models/sos_alert_model.dart';
import 'package:sire/features/alerts/domain/entities/alert_status.dart';
import 'package:sire/features/alerts/domain/entities/sos_alert.dart';
import 'package:sire/features/alerts/domain/entities/sos_source.dart';

/// Serialización JSON de la alerta (modo local). Verifica que ningún campo se
/// pierda, incluida la trazabilidad "atendida por […]".
void main() {
  test('round-trip conserva todos los campos y la trazabilidad', () {
    final a = SosAlert(
      id: '20260908-100000-1234',
      userId: 'u1',
      userName: 'Juan',
      aldea: 'Centro',
      latitude: 14.87,
      longitude: -91.60,
      timestamp: DateTime(2026, 9, 8, 10, 0, 0),
      source: SosSource.powerButton,
      status: AlertStatus.atendida,
      categoria: 'Robo',
      atendidaEn: DateTime(2026, 9, 8, 10, 2, 30),
      atendidaPor: 'cocode-1',
      atendidaPorNombre: 'Ana COCODE',
    );

    final back = SosAlertModel.decodeList(SosAlertModel.encodeList([a])).single;

    expect(back, a);
    expect(back.atendidaPor, 'cocode-1');
    expect(back.atendidaPorNombre, 'Ana COCODE');
  });
}
