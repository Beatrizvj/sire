import 'package:equatable/equatable.dart';

/// Lectura de ubicación devuelta por la capa de datos.
class LocationReading extends Equatable {
  const LocationReading({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.address,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final String? address;

  @override
  List<Object?> get props => [latitude, longitude, accuracy, address];
}
