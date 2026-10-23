import 'package:flutter_test/flutter_test.dart';
import 'package:sire/features/alerts/domain/entities/alert_status.dart';
import 'package:sire/features/alerts/domain/entities/sos_alert.dart';
import 'package:sire/features/alerts/domain/entities/sos_source.dart';
import 'package:sire/features/alerts/domain/repositories/alert_repository.dart';
import 'package:sire/features/alerts/domain/usecases/trigger_sos.dart';
import 'package:sire/features/location/domain/entities/location_reading.dart';
import 'package:sire/features/location/domain/repositories/location_repository.dart';

class _UbicacionFija implements LocationRepository {
  @override
  Future<LocationReading> getCurrentLocation() async =>
      const LocationReading(latitude: 14.87, longitude: -91.60, accuracy: 5);
}

/// Repositorio que solo cuenta cuántas alertas se guardaron.
class _RepoEspia implements AlertRepository {
  final guardadas = <SosAlert>[];

  @override
  Future<void> saveAlert(SosAlert alert) async => guardadas.add(alert);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Cuenta de revisión (revisor de Google Play): el SOS se simula y no llega a
/// Firestore ni a las autoridades.
void main() {
  test('una cuenta normal guarda la alerta', () async {
    final repo = _RepoEspia();
    final r = await TriggerSos(
      locationRepository: _UbicacionFija(),
      alertRepository: repo,
    ).call(SosSource.screenButton, userId: 'u1');

    expect(r.simulada, isFalse);
    expect(repo.guardadas, hasLength(1));
    expect(r.alert.status, AlertStatus.pendiente);
  });

  test('una cuenta de revisión simula el SOS y no guarda nada', () async {
    final repo = _RepoEspia();
    final r = await TriggerSos(
      locationRepository: _UbicacionFija(),
      alertRepository: repo,
    ).call(SosSource.screenButton, userId: 'revisor', simular: true);

    expect(r.simulada, isTrue);
    expect(repo.guardadas, isEmpty);
    expect(r.alert.latitude, 14.87);
    // No dice "Compartiendo tu ubicación en vivo".
    expect(r.alert.seguimientoTerminado(), isTrue);
  });
}
