import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => const PermissionService(),
);

/// Centraliza la solicitud de permisos del sistema.
///
/// El permiso de ubicación en primer plano lo gestiona `geolocator` dentro del
/// data source; aquí quedan los que necesita el servicio nativo (notificaciones
/// y, para endurecimiento futuro, ubicación en segundo plano).
class PermissionService {
  const PermissionService();

  /// Necesario para que la notificación del servicio en segundo plano sea
  /// visible en Android 13+.
  Future<bool> ensureNotifications() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Ubicación en primer plano. OBLIGATORIA antes de arrancar el servicio de
  /// detección: en Android 14+ un servicio en primer plano de tipo "location"
  /// exige este permiso concedido, o el sistema mata la app (SecurityException).
  Future<bool> ensureLocationWhenInUse() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted;
  }

  /// Ubicación en segundo plano ("Permitir todo el tiempo"). Sin ella, cuando
  /// Android reinicia el servicio del botón de encendido, este pierde el acceso
  /// al GPS y el SOS llega sin ubicación. En Android 11+ el sistema lleva al
  /// usuario a los ajustes de la app para elegir esa opción.
  Future<bool> ensureBackgroundLocation() async {
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }

  /// true si ya está concedido "Permitir todo el tiempo".
  Future<bool> hasBackgroundLocation() => Permission.locationAlways.isGranted;
}
