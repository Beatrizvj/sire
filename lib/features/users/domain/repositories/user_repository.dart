import '../entities/app_user.dart';

/// Contrato de persistencia de perfiles de usuario.
abstract interface class UserRepository {
  Future<AppUser?> getUser(String id);

  /// Perfil de un usuario EN TIEMPO REAL: permite reaccionar a cambios de rol,
  /// aprobación o contactos de confianza (RF-11) sin volver a iniciar sesión.
  Stream<AppUser?> watchUser(String id);

  Future<void> saveUser(AppUser user);

  /// Elimina el perfil de un usuario (colección `usuarios`). No borra su cuenta
  /// de Authentication (eso requiere privilegios de administrador).
  Future<void> deleteUser(String id);

  /// Todos los usuarios en tiempo real (para la Gestión de la Municipalidad).
  Stream<List<AppUser>> watchAllUsers();

  /// COCODE(s) aprobados de una aldea, en tiempo real. Sirve para que el
  /// CIUDADANO vea el contacto (teléfono) del COCODE de su aldea sin poder leer
  /// el resto de usuarios. Filtra por rol y aldea en la consulta.
  Stream<List<AppUser>> watchCocodesDeAldea(String aldea);
}
