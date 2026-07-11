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

  /// Ubicación en segundo plano (para capturar GPS con la pantalla bloqueada;
  /// se usará al endurecer el botón físico).
  Future<bool> ensureBackgroundLocation() async {
    final status = await Permission.locationAlways.request();
    return status.isGranted;
  }
}
