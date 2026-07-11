import 'package:equatable/equatable.dart';

/// Usuario autenticado (identidad). El perfil extendido es [AppUser] en la
/// feature `users`.
class AuthUser extends Equatable {
  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
  });

  final String uid;
  final String? email;
  final String? displayName;

  @override
  List<Object?> get props => [uid, email, displayName];
}
