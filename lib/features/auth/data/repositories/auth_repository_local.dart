import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Implementación local de [AuthRepository] para la demo sin Firebase.
///
/// Acepta cualquier credencial válida y persiste la "sesión" en
/// shared_preferences. El `uid` es determinista por correo para que el perfil
/// asociado se conserve entre inicios de sesión.
class AuthRepositoryLocal implements AuthRepository {
  AuthRepositoryLocal(this._prefs) {
    _current = _load();
  }

  final SharedPreferences _prefs;
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();

  static const String _key = 'sire_auth_user';
  AuthUser? _current;

  AuthUser? _load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AuthUser(
        uid: map['uid'] as String,
        email: map['email'] as String?,
        displayName: map['displayName'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist(AuthUser? user) async {
    if (user == null) {
      await _prefs.remove(_key);
    } else {
      await _prefs.setString(
        _key,
        jsonEncode({
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
        }),
      );
    }
    _current = user;
    _controller.add(user);
  }

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty || password.isEmpty) {
      throw Exception('Ingresa tu correo y contraseña.');
    }
    final user = AuthUser(
      uid: 'local-${email.trim().toLowerCase().hashCode}',
      email: email.trim(),
      displayName: _current?.displayName,
    );
    await _persist(user);
    return user;
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    if (email.trim().isEmpty || password.length < 6) {
      throw Exception('Correo válido y contraseña de al menos 6 caracteres.');
    }
    final user = AuthUser(
      uid: 'local-${email.trim().toLowerCase().hashCode}',
      email: email.trim(),
      displayName: displayName?.trim(),
    );
    await _persist(user);
    return user;
  }

  @override
  Future<void> signOut() => _persist(null);
}
