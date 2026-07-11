import '../entities/location_reading.dart';

/// Contrato para obtener la ubicación actual (implementado con geolocator en
/// la capa de datos). Puede lanzar las excepciones de `core/error/exceptions`.
abstract interface class LocationRepository {
  Future<LocationReading> getCurrentLocation();
}
