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
      // Recomendación post-Beta: en lugar de bloquear el SOS y pedirle al
      // usuario que active el GPS a mano, mostramos el diálogo de sistema de UN
      // TOQUE (Google Play Services) para encenderlo sin salir de la app; así la
      // alerta sale de inmediato con ubicación. Android no permite activarlo de
      // forma 100 % silenciosa: el de un toque es el máximo que ofrece.
      serviceEnabled = await _activarUbicacionUnToque();
    }
    if (!serviceEnabled) {
      // Aun sin GPS no perdemos la emergencia: si hay una última ubicación
      // conocida, la alerta se envía con ella; solo si tampoco existe, fallamos.
      final ultima = await Geolocator.getLastKnownPosition();
      if (ultima == null) {
        throw const LocationServiceDisabledException();
      }
      return _lecturaDesde(ultima);
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
