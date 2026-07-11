import 'package:geocoding/geocoding.dart';
// geolocator también define LocationServiceDisabledException; usamos la nuestra.
import 'package:geolocator/geolocator.dart' hide LocationServiceDisabledException;

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/location_reading.dart';
import '../../domain/repositories/location_repository.dart';

/// Implementación de [LocationRepository] con `geolocator` (GPS) y
/// `geocoding` (dirección). No requiere API key.
class LocationRepositoryGeolocator implements LocationRepository {
  const LocationRepositoryGeolocator();

  @override
  Future<LocationReading> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationPermissionDeniedException();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionPermanentlyDeniedException();
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );

    return LocationReading(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      address: await _reverseGeocode(position.latitude, position.longitude),
    );
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final parts = <String?>[
        p.street,
        p.subLocality,
        p.locality,
        p.administrativeArea,
        p.country,
      ].where((e) => e != null && e.trim().isNotEmpty).cast<String>();
      final joined = parts.join(', ');
      return joined.isEmpty ? null : joined;
    } catch (_) {
      // El reverse geocoding puede fallar sin conexión; la alerta igual se envía.
      return null;
    }
  }
}
