import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Puente con el código nativo Android que detecta las 3 pulsaciones del
/// botón de encendido (ver `PowerButtonService.kt`).
///
/// - [MethodChannel] `sire/power_control`: iniciar / detener el servicio.
/// - [EventChannel] `sire/power_events`: recibe `'sos_triggered'` cuando se
///   detecta el patrón.
final powerButtonBridgeProvider = Provider<PowerButtonBridge>((ref) {
  final bridge = PowerButtonBridge();
  ref.onDispose(bridge.dispose);
  return bridge;
});

class PowerButtonBridge {
  static const MethodChannel _control = MethodChannel('sire/power_control');
  static const EventChannel _events = EventChannel('sire/power_events');

  Stream<String>? _stream;

  /// Flujo de eventos emitidos por el servicio nativo.
  Stream<String> get events {
    _stream ??=
        _events.receiveBroadcastStream().map((event) => event.toString());
    return _stream!;
  }

  /// Inicia la detección nativa. Pasa el [uid] para que el servicio pueda
  /// etiquetar la alerta (idUsuario) al guardarla en Firestore por su cuenta.
  Future<bool> startDetection(String uid, String nombre) =>
      _invokeBool('startDetection', {'uid': uid, 'nombre': nombre});

  Future<bool> stopDetection() => _invokeBool('stopDetection');

  /// Consulta si el servicio de detección está corriendo ahora mismo, para que
  /// el switch refleje el estado real al abrir o volver a la app.
  Future<bool> isDetectionRunning() => _invokeBool('isDetectionRunning');

  Future<bool> isIgnoringBatteryOptimizations() =>
      _invokeBool('isIgnoringBatteryOptimizations');

  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _control.invokeMethod<void>('requestIgnoreBatteryOptimizations');
    } catch (_) {
      // Silencioso: si el fabricante no expone el ajuste, no es crítico.
    }
  }

  Future<bool> _invokeBool(String method, [Map<String, dynamic>? args]) async {
    try {
      final result = await _control.invokeMethod<bool>(method, args);
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // Ocurre en pruebas o en plataformas sin la implementación nativa.
      return false;
    }
  }

  void dispose() => _stream = null;
}
