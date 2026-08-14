import '../entities/auth_user.dart';

/// Contrato de autenticación. Implementado con Firebase Auth (producción) o
/// localmente (demo sin backend).
abstract interface class AuthRepository {
  /// Usuario actual (sincrónico), o null si no hay sesión.
  AuthUser? get currentUser;

  /// Emite el usuario en cada cambio de sesión (login / logout).
  Stream<AuthUser?> authStateChanges();

  Future<AuthUser> signIn({required String email, required String password});

  Future<AuthUser> register({
    required String email,
    required String password,
    String? displayName,
  });

  Future<void> signOut();

  /// Envía un correo para restablecer la contraseña.
  Future<void> sendPasswordReset(String email);

  /// Cambia la contraseña del usuario en sesión. Reautentica con la contraseña
  /// actual antes de aplicar la nueva (requisito de seguridad de Firebase).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}
