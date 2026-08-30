import '../entities/alert_status.dart';
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

  /// Todas las alertas de la comunidad en tiempo real (Municipalidad).
  Stream<List<SosAlert>> watchAllAlerts();

  /// Alertas de UNA aldea en tiempo real (ruteo por aldea del COCODE). Filtra en
  /// la CONSULTA (no en el cliente) para cumplir la regla de Firestore que
  /// restringe al COCODE a leer solo las alertas de su aldea.
  Stream<List<SosAlert>> watchAlertsByAldea(String aldea);

  /// Cambia el estado de una alerta (atender / resolver / falsa alarma).
  Future<void> updateStatus(String id, AlertStatus status);

  /// R3: asigna/cambia la categoría del incidente (clasificar una alerta).
  Future<void> updateCategoria(String id, String categoria);
}
