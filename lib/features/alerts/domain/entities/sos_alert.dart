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
    this.userName,
    this.status = AlertStatus.pendiente,
    this.type = 'SOS',
    this.address,
    this.accuracy,
    this.categoria,
  });

  final String id;

  /// idUsuario (uid). Nulo en modo local sin sesión.
  final String? userId;

  /// Nombre del ciudadano (nombreUsuario), para que la autoridad lo identifique.
  final String? userName;
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

  /// R3: categoría del incidente (Robo, Asalto, Persona sospechosa). Nula =
  /// "sin especificar" (p. ej. SOS por botón de encendido, a clasificar después).
  final String? categoria;

  SosAlert copyWith({AlertStatus? status, String? categoria}) => SosAlert(
        id: id,
        userId: userId,
        userName: userName,
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        source: source,
        status: status ?? this.status,
        type: type,
        address: address,
        accuracy: accuracy,
        categoria: categoria ?? this.categoria,
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        userName,
        latitude,
        longitude,
        timestamp,
        source,
        status,
        type,
        address,
        accuracy,
        categoria,
      ];
}
