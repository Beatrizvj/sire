import 'package:equatable/equatable.dart';

import 'user_role.dart';

/// Perfil de un usuario en Firestore (colección `usuarios`).
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.nombre,
    required this.telefono,
    this.email,
    this.rol = UserRole.ciudadano,
    this.aldea = '',
    this.activo = true,
  });

  final String id;
  final String nombre;
  final String telefono;
  final String? email;
  final UserRole rol;
  final String aldea;
  final bool activo;

  AppUser copyWith({
    String? nombre,
    String? telefono,
    String? email,
    UserRole? rol,
    String? aldea,
    bool? activo,
  }) =>
      AppUser(
        id: id,
        nombre: nombre ?? this.nombre,
        telefono: telefono ?? this.telefono,
        email: email ?? this.email,
        rol: rol ?? this.rol,
        aldea: aldea ?? this.aldea,
        activo: activo ?? this.activo,
      );

  @override
  List<Object?> get props => [id, nombre, telefono, email, rol, aldea, activo];
}
