import 'package:equatable/equatable.dart';

import 'sos_source.dart';

/// Una alerta de emergencia (SOS) generada por el ciudadano.
class SosAlert extends Equatable {
  const SosAlert({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.source,
    this.address,
    this.accuracy,
  });

  final String id;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final SosSource source;

  /// Dirección aproximada (reverse geocoding); puede ser nula sin conexión.
  final String? address;

  /// Precisión del GPS en metros.
  final double? accuracy;

  @override
  List<Object?> get props =>
      [id, latitude, longitude, timestamp, source, address, accuracy];
}
