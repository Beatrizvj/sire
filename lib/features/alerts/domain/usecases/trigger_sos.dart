import '../entities/sos_alert.dart';
import '../entities/sos_source.dart';
import '../repositories/alert_repository.dart';
import '../repositories/location_repository.dart';

/// Caso de uso central de SIRE: generar una alerta SOS.
///
/// 1. Obtiene la ubicación actual (GPS + dirección).
/// 2. Construye la [SosAlert].
/// 3. La persiste mediante [AlertRepository].
class TriggerSos {
  const TriggerSos({
    required this.locationRepository,
    required this.alertRepository,
  });

  final LocationRepository locationRepository;
  final AlertRepository alertRepository;

  Future<SosAlert> call(SosSource source) async {
    final reading = await locationRepository.getCurrentLocation();

    final alert = SosAlert(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      latitude: reading.latitude,
      longitude: reading.longitude,
      accuracy: reading.accuracy,
      address: reading.address,
      timestamp: DateTime.now(),
      source: source,
    );

    await alertRepository.saveAlert(alert);
    return alert;
  }
}
