import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/error/exceptions.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../data/repositories/alert_repository_firestore.dart';
import '../../data/repositories/alert_repository_local.dart';
import '../../domain/entities/sos_alert.dart';
import '../../domain/entities/sos_source.dart';
import '../../domain/repositories/alert_repository.dart';
import '../../domain/usecases/trigger_sos.dart';

/// Repositorio de alertas. Cambia local ↔ Firestore con [AppConfig.firebaseEnabled].
final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  if (AppConfig.firebaseEnabled) {
    return AlertRepositoryFirestore(
      FirebaseFirestore.instance,
      FirebaseAuth.instance,
    );
  }
  return AlertRepositoryLocal(ref.watch(sharedPreferencesProvider));
});

final triggerSosProvider = Provider<TriggerSos>(
  (ref) => TriggerSos(
    locationRepository: ref.watch(locationRepositoryProvider),
    alertRepository: ref.watch(alertRepositoryProvider),
  ),
);

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
      lastError: lastError, // transitorio
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
      final userId = ref.read(authControllerProvider).user?.uid;
      final alert = await ref.read(triggerSosProvider).call(source, userId: userId);
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
