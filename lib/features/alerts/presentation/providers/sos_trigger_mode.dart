import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/app_providers.dart';

/// Cómo puede el ciudadano disparar un SOS. Preferencia **persistida**.
///
/// La usa la pantalla de SOS para mostrar/ocultar el botón en pantalla y/o la
/// detección por botón de encendido, según lo que el ciudadano elija.
enum SosTriggerMode {
  pantalla, // solo el botón grande en pantalla
  encendido, // solo el botón de encendido (servicio nativo)
  ambos; // los dos (por defecto)

  String get label => switch (this) {
        SosTriggerMode.pantalla => 'Solo botón en pantalla',
        SosTriggerMode.encendido => 'Solo botón de encendido',
        SosTriggerMode.ambos => 'Ambos',
      };

  /// ¿Se muestra el botón SOS en pantalla?
  bool get usaPantalla => this != SosTriggerMode.encendido;

  /// ¿Se usa la detección por botón de encendido?
  bool get usaEncendido => this != SosTriggerMode.pantalla;
}

const _kSosTriggerKey = 'sire_sos_trigger_mode';

final sosTriggerModeProvider =
    NotifierProvider<SosTriggerModeController, SosTriggerMode>(
        SosTriggerModeController.new);

class SosTriggerModeController extends Notifier<SosTriggerMode> {
  @override
  SosTriggerMode build() {
    final stored =
        ref.watch(sharedPreferencesProvider).getString(_kSosTriggerKey);
    return SosTriggerMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => SosTriggerMode.ambos,
    );
  }

  /// Cambia y guarda la preferencia.
  Future<void> set(SosTriggerMode mode) async {
    if (mode == state) return;
    state = mode;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kSosTriggerKey, mode.name);
  }
}
