/// Representación de errores de dominio (Clean Architecture).
///
/// Se usa como valor de retorno controlado en los casos de uso en lugar de
/// lanzar excepciones hasta la capa de presentación.
sealed class Failure {
  const Failure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// El servicio de ubicación (GPS) está deshabilitado en el dispositivo.
class LocationServiceFailure extends Failure {
  const LocationServiceFailure([super.message = 'El GPS está desactivado.']);
}

/// El usuario no concedió el permiso de ubicación.
class PermissionFailure extends Failure {
  const PermissionFailure([
    super.message = 'Permiso de ubicación denegado.',
  ]);
}

/// Error no previsto.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Ocurrió un error inesperado.']);
}
