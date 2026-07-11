import '../entities/sos_alert.dart';

/// Contrato de persistencia de alertas.
///
/// En v1 se implementa localmente (shared_preferences); en el Hito 3 se
/// implementará contra Cloud Firestore sin cambiar esta interfaz ni los casos
/// de uso que la consumen.
abstract interface class AlertRepository {
  Future<List<SosAlert>> getAlerts();
  Future<void> saveAlert(SosAlert alert);
  Future<void> clear();
}
