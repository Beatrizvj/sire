import '../entities/app_user.dart';

/// Contrato de persistencia de perfiles de usuario.
abstract interface class UserRepository {
  Future<AppUser?> getUser(String id);
  Future<void> saveUser(AppUser user);
}
