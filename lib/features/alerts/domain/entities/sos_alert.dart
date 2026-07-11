import 'package:equatable/equatable.dart';

import 'alert_status.dart';
import 'sos_source.dart';

/// Una alerta de emergencia (SOS) generada por el ciudadano.
///
/// Los campos mapean el esquema de Firestore de la tesis:
/// `idUsuario`, `fecha`, `latitud`, `longitud`, `estado`, `tipo`.
class SosAlert extends Equatable {
  const SosAlert({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.source,
    this.userId,
    this.status = AlertStatus.pendiente,
    this.type = 'SOS',
    this.address,
    this.accuracy,
  });

  final String id;

  /// idUsuario (uid). Nulo en modo local sin sesión.
  final String? userId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final SosSource source;
  final AlertStatus status;
  final String type;

  /// Dirección aproximada (reverse geocoding); puede ser nula sin conexión.
  final String? address;

  /// Precisión del GPS en metros.
  final double? accuracy;

  SosAlert copyWith({AlertStatus? status}) => SosAlert(
        id: id,
        userId: userId,
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        source: source,
        status: status ?? this.status,
        type: type,
        address: address,
        accuracy: accuracy,
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        latitude,
        longitude,
        timestamp,
        source,
        status,
        type,
        address,
        accuracy,
      ];
}
