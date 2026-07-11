import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/location_repository_geolocator.dart';
import '../../domain/entities/location_reading.dart';
import '../../domain/repositories/location_repository.dart';

/// Implementación de ubicación (geolocator). Es la única fuente de GPS de la app.
final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => const LocationRepositoryGeolocator(),
);

/// Obtiene la ubicación actual bajo demanda (útil para el mapa o para mostrar
/// la posición sin disparar un SOS).
final currentLocationProvider = FutureProvider.autoDispose<LocationReading>(
  (ref) => ref.watch(locationRepositoryProvider).getCurrentLocation(),
);
