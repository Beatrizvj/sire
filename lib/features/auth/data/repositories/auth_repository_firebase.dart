import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Implementación de [AuthRepository] con Firebase Auth.
class AuthRepositoryFirebase implements AuthRepository {
  AuthRepositoryFirebase(this._auth);

  final FirebaseAuth _auth;

  AuthUser? _map(User? user) => user == null
      ? null
      : AuthUser(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
        );

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AuthUser?> authStateChanges() => _auth.authStateChanges().map(_map);

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _map(credential.user)!;
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user!;
    if (displayName != null && displayName.trim().isNotEmpty) {
      await user.updateDisplayName(displayName.trim());
    }
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: displayName?.trim() ?? user.displayName,
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteCurrentUser() async {
    // La cuenta se acaba de crear (login reciente), así que delete() no exige
    // reautenticación. Si no hay usuario en sesión, no hace nada.
    await _auth.currentUser?.delete();
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No hay una sesión activa.',
      );
    }
    // Reautentica con la contraseña actual (Firebase lo exige para cambios
    // sensibles cuando la sesión no es reciente).
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }
}
