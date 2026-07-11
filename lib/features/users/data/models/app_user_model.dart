import 'dart:convert';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';

/// Serialización de [AppUser] (Firestore / JSON local).
class AppUserModel {
  const AppUserModel._();

  static Map<String, dynamic> toMap(AppUser user) => {
        'nombre': user.nombre,
        'telefono': user.telefono,
        'email': user.email,
        'rol': user.rol.value,
        'aldea': user.aldea,
        'activo': user.activo,
      };

  /// [id] se pasa aparte porque en Firestore es el id del documento.
  static AppUser fromMap(Map<String, dynamic> map, {required String id}) =>
      AppUser(
        id: id,
        nombre: map['nombre'] as String? ?? '',
        telefono: map['telefono'] as String? ?? '',
        email: map['email'] as String?,
        rol: UserRole.fromValue(map['rol'] as String? ?? 'ciudadano'),
        aldea: map['aldea'] as String? ?? '',
        activo: map['activo'] as bool? ?? true,
      );

  static String encode(AppUser user) =>
      jsonEncode(toMap(user)..['id'] = user.id);

  static AppUser decode(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return fromMap(map, id: map['id'] as String);
  }
}
