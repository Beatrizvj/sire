import 'package:flutter/foundation.dart';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/app_providers.dart';
import '../../../identity/data/identity_repository.dart';
import '../../../users/domain/entities/account_status.dart';
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

/// Imprime en la terminal (visible con `flutter run`) el registro del sistema
/// de acceso. Sale con etiqueta [SIRE-LOGIN] y hora, para seguir en vivo cada
/// intento: aprobado, fallido o bloqueado.
void logAcceso(String mensaje) {
  final hora = DateTime.now().toIso8601String().substring(11, 19);
  debugPrint('SIRE-LOGIN | [$hora] $mensaje');
}

/// Perfil (con rol) del usuario en sesión; null si no hay sesión. La app lo usa
/// para decidir qué mostrar: ciudadano → SOS · COCODE/Municipalidad → Bandeja.
final currentUserProfileProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(authControllerProvider).user?.uid;
  if (uid == null) return Stream<AppUser?>.value(null);
  // Perfil EN VIVO: reacciona a cambios de rol, aprobación o contactos de
  // confianza (RF-11) sin necesidad de volver a iniciar sesión.
  return ref.read(userRepositoryProvider).watchUser(uid).map((perfil) {
    if (perfil == null) {
      logAcceso(
        '🚫 BLOQUEADO · uid=$uid autenticado pero SIN perfil en la base '
        '(colección usuarios). No puede acceder a las instancias del proyecto.',
      );
    } else if (!perfil.activo) {
      logAcceso(
        '🚫 BLOQUEADO · uid=$uid · nombre="${perfil.nombre}" · '
        'rol=${perfil.rol.label} · cuenta DESACTIVADA (activo=false). Acceso denegado.',
      );
    } else {
      logAcceso(
        '📋 BASE DE DATOS OK · uid=$uid · nombre="${perfil.nombre}" · '
        'rol=${perfil.rol.label} · aldea="${perfil.aldea}" · '
        'acceso permitido a su instancia de ${perfil.rol.label}.',
      );
    }
    return perfil;
  });
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
    logAcceso('… INTENTO de inicio de sesión · correo=${email.trim()}');
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      state = state.copyWith(user: user, isBusy: false);
      logAcceso(
        '✅ APROBADO · login correcto · correo=${user.email} · uid=${user.uid}. '
        'Consultando su rol en la base de datos…',
      );
      return true;
    } catch (e) {
      logAcceso(
        '❌ FALLIDO · login incorrecto · correo=${email.trim()} · '
        'motivo="${_message(e)}"',
      );
      state = state.copyWith(isBusy: false, error: _message(e));
      return false;
    }
  }

  /// Registra un nuevo usuario. R1: NO se asigna rol ni acceso automáticamente.
  /// La cuenta nace [AccountStatus.pendienteRevision]; una autoridad (COCODE de
  /// la aldea o Municipalidad) la aprobará y le asignará el rol. El usuario solo
  /// declara la aldea a la que pertenece ([aldeaSolicitada]).
  Future<bool> register({
    required String nombre,
    required String telefono,
    required String email,
    required String password,
    String aldeaSolicitada = '',
    Uint8List? dpiAnverso,
    Uint8List? dpiReverso,
  }) async {
    state = state.copyWith(isBusy: true);
    try {
      final authUser = await ref.read(authRepositoryProvider).register(
            email: email,
            password: password,
            displayName: nombre,
          );
      // R2 (blindado): sube las fotos del DPI ANTES de crear el perfil. Se hace
      // dentro del controlador (no en la pantalla de registro) para que la
      // subida no se interrumpa al navegar a "Cuenta en revisión". Y al ir
      // PRIMERO, si la subida falla no se crea el perfil: así NUNCA queda una
      // cuenta sin DPI en la cola de aprobaciones.
      final repo = ref.read(identityRepositoryProvider);
      if (dpiAnverso != null) {
        await repo.subir(
            uid: authUser.uid,
            lado: IdentityRepository.anverso,
            bytes: dpiAnverso);
      }
      if (dpiReverso != null) {
        await repo.subir(
            uid: authUser.uid,
            lado: IdentityRepository.reverso,
            bytes: dpiReverso);
      }
      // Ya con las fotos guardadas, crea el perfil PENDIENTE DE REVISIÓN
      // (sin rol efectivo ni acceso).
      await ref.read(userRepositoryProvider).saveUser(
            AppUser(
              id: authUser.uid,
              nombre: nombre,
              telefono: telefono,
              email: email,
              rol: UserRole.ciudadano, // marcador; el acceso lo decide el estado
              estadoCuenta: AccountStatus.pendienteRevision,
              aldeaSolicitada: aldeaSolicitada,
              activo: true,
            ),
          );
      state = state.copyWith(user: authUser, isBusy: false);
      return true;
    } catch (e) {
      // Registro incompleto (p. ej. no se pudo guardar la foto del DPI): cierra
      // la sesión recién creada para NO dejar un usuario autenticado sin perfil.
      try {
        await ref.read(authRepositoryProvider).signOut();
      } catch (_) {}
      state = state.copyWith(isBusy: false, error: _message(e), clearUser: true);
      return false;
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = state.copyWith(clearUser: true);
  }

  /// Envía el correo de restablecimiento de contraseña. Devuelve true si se
  /// envió correctamente; si falla, el mensaje queda en [AuthState.error].
  Future<bool> sendPasswordReset(String email) async {
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      return true;
    } catch (e) {
      state = state.copyWith(error: _message(e));
      return false;
    }
  }

  /// Cambia la contraseña del usuario en sesión. Devuelve true si se aplicó; si
  /// falla, el motivo queda en [AuthState.error].
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await ref.read(authRepositoryProvider).changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      return true;
    } catch (e) {
      state = state.copyWith(error: _message(e));
      return false;
    }
  }

  String _message(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => 'Correo inválido.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'La contraseña actual es incorrecta.',
        'email-already-in-use' => 'Ese correo ya está registrado.',
        'weak-password' => 'Contraseña muy débil (mínimo 6 caracteres).',
        'requires-recent-login' =>
          'Por seguridad, vuelve a iniciar sesión y reintenta.',
        'network-request-failed' => 'Sin conexión. Revisa tu internet.',
        // Firebase bloquea temporalmente tras varios intentos fallidos
        // (protección contra fuerza bruta). El usuario debe esperar unos minutos.
        'too-many-requests' =>
          'Demasiados intentos fallidos. Espera unos minutos e inténtalo de nuevo.',
        _ => error.message ?? 'Error de autenticación.',
      };
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
