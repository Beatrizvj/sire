import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/app_providers.dart';
import '../../../users/domain/entities/app_user.dart';
import '../../../users/domain/entities/user_role.dart';
import '../../../users/presentation/providers/users_providers.dart';
import '../../data/repositories/auth_repository_firebase.dart';
import '../../data/repositories/auth_repository_local.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Repositorio de autenticación. Cambia local ↔ Firebase con [AppConfig.firebaseEnabled].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AppConfig.firebaseEnabled) {
    return AuthRepositoryFirebase(FirebaseAuth.instance);
  }
  return AuthRepositoryLocal(ref.watch(sharedPreferencesProvider));
});

class AuthState extends Equatable {
  const AuthState({
    this.user,
    this.isBusy = false,
    this.error,
    this.initialized = false,
  });

  final AuthUser? user;
  final bool isBusy;
  final String? error;
  final bool initialized;

  bool get isLoggedIn => user != null;

  AuthState copyWith({
    AuthUser? user,
    bool clearUser = false,
    bool? isBusy,
    String? error,
    bool? initialized,
  }) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        isBusy: isBusy ?? this.isBusy,
        error: error, // transitorio: se limpia si no se pasa
        initialized: initialized ?? this.initialized,
      );

  @override
  List<Object?> get props => [user, isBusy, error, initialized];
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repo = ref.watch(authRepositoryProvider);
    final sub = repo.authStateChanges().listen((user) {
      state = state.copyWith(
        user: user,
        clearUser: user == null,
        initialized: true,
      );
    });
    ref.onDispose(sub.cancel);
    return AuthState(user: repo.currentUser, initialized: true);
  }

  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(isBusy: true);
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      state = state.copyWith(user: user, isBusy: false);
      return true;
    } catch (e) {
      state = state.copyWith(isBusy: false, error: _message(e));
      return false;
    }
  }

  Future<bool> register({
    required String nombre,
    required String telefono,
    required String email,
    required String password,
    UserRole rol = UserRole.ciudadano,
  }) async {
    state = state.copyWith(isBusy: true);
    try {
      final authUser = await ref.read(authRepositoryProvider).register(
            email: email,
            password: password,
            displayName: nombre,
          );
      // Crea el perfil en la colección de usuarios.
      await ref.read(userRepositoryProvider).saveUser(
            AppUser(
              id: authUser.uid,
              nombre: nombre,
              telefono: telefono,
              email: email,
              rol: rol,
            ),
          );
      state = state.copyWith(user: authUser, isBusy: false);
      return true;
    } catch (e) {
      state = state.copyWith(isBusy: false, error: _message(e));
      return false;
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = state.copyWith(clearUser: true);
  }

  String _message(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'Correo inválido.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Correo o contraseña incorrectos.',
        'email-already-in-use' => 'Ese correo ya está registrado.',
        'weak-password' => 'Contraseña muy débil (mínimo 6 caracteres).',
        'network-request-failed' => 'Sin conexión. Revisa tu internet.',
        _ => error.message ?? 'Error de autenticación.',
      };
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
