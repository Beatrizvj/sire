import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/account_status.dart';
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
        'estadoCuenta': user.estadoCuenta.value,
        'aldeaSolicitada': user.aldeaSolicitada,
        'aprobadoPor': user.aprobadoPor,
        'aprobadoEn':
            user.aprobadoEn == null ? null : Timestamp.fromDate(user.aprobadoEn!),
        'puedeVerIdentidad': user.puedeVerIdentidad,
        'contactosConfianza': user.contactosConfianza,
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
        // Documentos antiguos sin `estadoCuenta` se consideran aprobados.
        estadoCuenta: AccountStatus.fromValue(map['estadoCuenta'] as String?),
        aldeaSolicitada: map['aldeaSolicitada'] as String? ?? '',
        aprobadoPor: map['aprobadoPor'] as String?,
        aprobadoEn: _toDate(map['aprobadoEn']),
        puedeVerIdentidad: map['puedeVerIdentidad'] as bool? ?? false,
        contactosConfianza:
            (map['contactosConfianza'] as List<dynamic>?)?.cast<String>() ??
                const [],
      );

  static DateTime? _toDate(Object? raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }

  static String encode(AppUser user) {
    final map = toMap(user)..['id'] = user.id;
    // El JSON local no maneja Timestamp: se guarda la fecha como ISO-8601.
    map['aprobadoEn'] = user.aprobadoEn?.toIso8601String();
    return jsonEncode(map);
  }

  static AppUser decode(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return fromMap(map, id: map['id'] as String);
  }
}
