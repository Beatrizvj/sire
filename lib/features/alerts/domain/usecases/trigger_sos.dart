import 'dart:async';

import '../../../location/domain/repositories/location_repository.dart';
import '../entities/alert_status.dart';
import '../entities/sos_alert.dart';
import '../entities/sos_source.dart';
import '../repositories/alert_repository.dart';

/// Resultado de disparar un SOS.
class SosResult {
  const SosResult(this.alert, {this.enCola = false});

  final SosAlert alert;

  /// true si la alerta se guardó localmente pero el servidor aún no la confirmó
  /// (sin señal). Firestore la sincroniza al recuperar la conexión; la alerta
  /// NO se pierde.
  final bool enCola;
}

/// Caso de uso central de SIRE: generar una alerta SOS.
///
/// 1. Obtiene la ubicación actual (GPS + dirección) vía [LocationRepository].
/// 2. Construye la [SosAlert] (estado `pendiente`, tipo `SOS`).
/// 3. La persiste mediante [AlertRepository]. Si el servidor no confirma dentro
///    de [_esperaConfirmacion] (sin señal), devuelve [SosResult.enCola] = true:
///    Firestore ya guardó la alerta en su caché local y la sincronizará después.
class TriggerSos {
  const TriggerSos({
    required this.locationRepository,
    required this.alertRepository,
  });

  final LocationRepository locationRepository;
  final AlertRepository alertRepository;

  /// Tiempo máximo que se espera la confirmación del servidor antes de asumir
  /// que no hay señal y dar la alerta por guardada en cola (offline).
  static const Duration _esperaConfirmacion = Duration(seconds: 5);

  Future<SosResult> call(
    SosSource source, {
    String? userId,
    String? categoria,
    String? aldea,
  }) async {
    final reading = await locationRepository.getCurrentLocation();

    final alert = SosAlert(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      userId: userId,
      aldea: aldea,
      latitude: reading.latitude,
      longitude: reading.longitude,
      accuracy: reading.accuracy,
      address: reading.address,
      timestamp: DateTime.now(),
      source: source,
      status: AlertStatus.pendiente,
      type: 'SOS',
      categoria: categoria,
    );

    var enCola = false;
    try {
      await alertRepository.saveAlert(alert).timeout(_esperaConfirmacion);
    } on TimeoutException {
      // Sin confirmación del servidor: Firestore guardó la escritura en su caché
      // local y la sincronizará al recuperar la conexión. La alerta NO se pierde.
      enCola = true;
    }
    return SosResult(alert, enCola: enCola);
  }
}
