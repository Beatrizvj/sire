import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Puente con el servicio nativo `AlertMonitorService`, que hace sonar la alarma
/// en el teléfono de las autoridades (COCODE / Municipalidad) cuando entra una
/// alerta, **aunque la app esté en segundo plano**.
///
/// MethodChannel `sire/alert_monitor`: `startMonitor` / `stopMonitor`.
final alertMonitorBridgeProvider = Provider<AlertMonitorBridge>(
  (ref) => const AlertMonitorBridge(),
);

class AlertMonitorBridge {
  const AlertMonitorBridge();

  static const MethodChannel _channel = MethodChannel('sire/alert_monitor');

  /// Inicia el monitoreo (arranca el servicio en primer plano).
  /// - [todos] = true: autoridad, oye TODAS las alertas.
  /// - [todos] = false: ciudadano contacto de confianza (RF-11), oye solo las
  ///   alertas de los uids en [contactos].
  Future<void> start({bool todos = true, List<String> contactos = const []}) =>
      _invoke('startMonitor', {'todos': todos, 'contactos': contactos});

  /// Detiene el monitoreo (al cerrar sesión o dejar de ser autoridad/contacto).
  Future<void> stop() => _invoke('stopMonitor');

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      await _channel.invokeMethod<bool>(method, args);
    } on PlatformException catch (_) {
      // Falla no crítica.
    } on MissingPluginException catch (_) {
      // Sin implementación nativa (web o pruebas): se ignora.
    }
  }
}
