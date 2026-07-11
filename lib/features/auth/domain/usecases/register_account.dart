import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

/// Caso de uso: crear una cuenta de autenticación.
///
/// La creación del perfil ([AppUser] en Firestore) la orquesta el
/// `AuthController` tras registrar la identidad.
class RegisterAccount {
  const RegisterAccount(this._repository);

  final AuthRepository _repository;

  Future<AuthUser> call({
    required String email,
    required String password,
    String? displayName,
  }) =>
      _repository.register(
        email: email,
        password: password,
        displayName: displayName,
      );
}
