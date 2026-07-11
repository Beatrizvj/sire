import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/app_providers.dart';
import '../../../../core/error/exceptions.dart';
import '../../data/repositories/alert_repository_local.dart';
import '../../data/repositories/location_repository_geolocator.dart';
import '../../domain/entities/sos_alert.dart';
import '../../domain/entities/sos_source.dart';
import '../../domain/repositories/alert_repository.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/usecases/trigger_sos.dart';

// --- Inyección de dependencias (Clean Architecture) ---

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => const LocationRepositoryGeolocator(),
);

final alertRepositoryProvider = Provider<AlertRepository>(
  (ref) => AlertRepositoryLocal(ref.watch(sharedPreferencesProvider)),
);

final triggerSosProvider = Provider<TriggerSos>(
  (ref) => TriggerSos(
    locationRepository: ref.watch(locationRepositoryProvider),
    alertRepository: ref.watch(alertRepositoryProvider),
  ),
);

// --- Estado de la UI de alertas ---

class AlertsState extends Equatable {
  const AlertsState({
    this.alerts = const [],
    this.isSending = false,
    this.lastError,
  });

  final List<SosAlert> alerts;
  final bool isSending;
  final String? lastError;

  AlertsState copyWith({
    List<SosAlert>? alerts,
    bool? isSending,
    String? lastError,
  }) {
    return AlertsState(
      alerts: alerts ?? this.alerts,
      isSending: isSending ?? this.isSending,
      // El error es transitorio: si no se pasa, se limpia.
      lastError: lastError,
    );
  }

  @override
  List<Object?> get props => [alerts, isSending, lastError];
}

final alertsControllerProvider =
    NotifierProvider<AlertsController, AlertsState>(AlertsController.new);

class AlertsController extends Notifier<AlertsState> {
  @override
  AlertsState build() {
    _restore();
    return const AlertsState();
  }

  Future<void> _restore() async {
    try {
      final alerts = await ref.read(alertRepositoryProvider).getAlerts();
      state = state.copyWith(alerts: alerts);
    } catch (_) {
      // Sin persistencia disponible (p. ej. en pruebas): se ignora.
    }
  }

  /// Dispara un SOS. Devuelve la alerta creada, o null si hubo un error
  /// (el mensaje queda en [AlertsState.lastError]).
  Future<SosAlert?> triggerSos(SosSource source) async {
    if (state.isSending) return null;
    state = state.copyWith(isSending: true);
    try {
      final alert = await ref.read(triggerSosProvider).call(source);
      state = state.copyWith(isSending: false, alerts: [alert, ...state.alerts]);
      return alert;
    } on LocationServiceDisabledException {
      state = state.copyWith(
        isSending: false,
        lastError: 'Activa el GPS del teléfono para enviar el SOS.',
      );
    } on LocationPermissionDeniedException {
      state = state.copyWith(
        isSending: false,
        lastError: 'Concede el permiso de ubicación para enviar el SOS.',
      );
    } on LocationPermissionPermanentlyDeniedException {
      state = state.copyWith(
        isSending: false,
        lastError:
            'Permiso de ubicación bloqueado. Actívalo en los Ajustes del sistema.',
      );
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        lastError: 'No se pudo enviar el SOS: $e',
      );
    }
    return null;
  }

  Future<void> clearHistory() async {
    await ref.read(alertRepositoryProvider).clear();
    state = state.copyWith(alerts: const []);
  }
}
