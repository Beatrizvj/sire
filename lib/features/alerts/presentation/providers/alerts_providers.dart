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
import '../../domain/entities/alert_status.dart';
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

/// Todas las alertas de la comunidad en tiempo real, para la Bandeja de
/// COCODE / Municipalidad. Solo la deben observar las autoridades: las reglas
/// de Firestore permiten a COCODE/Municipalidad leer todas; un ciudadano
/// recibiría permiso denegado.
final allAlertsProvider = StreamProvider.autoDispose<List<SosAlert>>(
  (ref) => ref.watch(alertRepositoryProvider).watchAllAlerts(),
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
    // Privacidad: el historial pertenece al usuario en sesión. Al cambiar de
    // cuenta (login/logout) cambia el uid, el controlador se reconstruye, la
    // lista se reinicia y se recarga la del nuevo usuario. Así una cuenta nunca
    // muestra el historial de otra.
    ref.watch(authControllerProvider.select((s) => s.user?.uid));
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

  /// Relee las alertas desde el repositorio (p. ej. tras un SOS guardado de
  /// forma nativa por el servicio del botón de encendido).
  Future<void> refresh() => _restore();

  /// Dispara un SOS. Devuelve la alerta creada, o null si hubo un error
  /// (el mensaje queda en [AlertsState.lastError]).
  Future<SosResult?> triggerSos(SosSource source, {String? categoria}) async {
    if (state.isSending) return null;
    state = state.copyWith(isSending: true);
    try {
      final userId = ref.read(authControllerProvider).user?.uid;
      final result = await ref
          .read(triggerSosProvider)
          .call(source, userId: userId, categoria: categoria);
      state = state.copyWith(
          isSending: false, alerts: [result.alert, ...state.alerts]);
      return result;
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

  /// Cambia el estado de una alerta (usado por la Bandeja de la autoridad).
  Future<void> updateStatus(String id, AlertStatus status) =>
      ref.read(alertRepositoryProvider).updateStatus(id, status);

  /// R3: clasifica una alerta con una categoría de incidente. Actualiza también
  /// la copia local para reflejarlo de inmediato en el historial del ciudadano.
  Future<void> updateCategoria(String id, String categoria) async {
    await ref.read(alertRepositoryProvider).updateCategoria(id, categoria);
    state = state.copyWith(alerts: [
      for (final a in state.alerts)
        a.id == id ? a.copyWith(categoria: categoria) : a,
    ]);
  }

  Future<void> clearHistory() async {
    await ref.read(alertRepositoryProvider).clear();
    state = state.copyWith(alerts: const []);
  }
}
