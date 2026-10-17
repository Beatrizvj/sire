import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart';
// geolocator también define LocationServiceDisabledException; usamos la nuestra.
import 'package:geolocator/geolocator.dart' hide LocationServiceDisabledException;
// Solo para el diálogo nativo de "activar ubicación" de un toque (requestService).
import 'package:location/location.dart' as loc;

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/location_reading.dart';
import '../../domain/repositories/location_repository.dart';

/// Implementación de [LocationRepository] con `geolocator` (GPS) y
/// `geocoding` (dirección). No requiere API key.
class LocationRepositoryGeolocator implements LocationRepository {
  const LocationRepositoryGeolocator();

  @override
  Future<LocationReading> getCurrentLocation() async {
    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Se ofrece el diálogo de UN TOQUE para activar la ubicación. Si el
      // ciudadano ACTIVA, el flujo de abajo obtiene la ubicación precisa (sin
      // tener que reenviar el SOS). Si NO activa, se usa la última ubicación
      // conocida; y si tampoco existe, se lanza para que el SOS se envíe IGUAL,
      // "sin ubicación" (ver TriggerSos), de modo que la alerta llegue sí o sí.
      // Android NO permite encender el GPS de forma automática: el de un toque
      // es el máximo para una app instalada por el ciudadano en su teléfono.
      serviceEnabled = await _activarUbicacionUnToque();
      if (!serviceEnabled) {
        try {
          final ultima = await Geolocator.getLastKnownPosition();
          if (ultima != null) return _lecturaDesde(ultima);
        } catch (_) {
          // sin última ubicación: el SOS se enviará sin ubicación.
        }
        throw const LocationServiceDisabledException();
      }
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

    // Intenta una posición fresca de alta precisión, pero sin bloquear el SOS:
    // si no responde pronto (típico en interiores), cae a la última ubicación
    // conocida para que la alerta SIEMPRE se envíe.
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } on Exception {
      position = await Geolocator.getLastKnownPosition();
    }
    if (position == null) {
      throw const LocationServiceDisabledException();
    }

    return _lecturaDesde(position);
  }

  /// Muestra el diálogo nativo de UN TOQUE para activar la ubicación del
  /// dispositivo (Play Services). Devuelve `true` si quedó activada. Solo aplica
  /// en Android con la app en primer plano; en web, o si el usuario rechaza,
  /// devuelve `false` sin lanzar excepción (el llamador decide el respaldo).
  Future<bool> _activarUbicacionUnToque() async {
    if (kIsWeb) return false;
    try {
      final servicio = loc.Location();
      if (await servicio.serviceEnabled()) return true;
      return await servicio.requestService();
    } catch (_) {
      return false;
    }
  }

  Future<LocationReading> _lecturaDesde(Position position) async =>
      LocationReading(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        address: await _reverseGeocode(position.latitude, position.longitude),
      );

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      // Acota el peor caso: en redes rurales lentas, el reverse geocoding no
      // debe retrasar el SOS más de 2 s. Si expira, la alerta se envía con las
      // coordenadas (sin dirección) y el panel las muestra igual.
      final placemarks = await Geocoding()
          .placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 2));
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
