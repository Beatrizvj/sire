import 'package:equatable/equatable.dart';

import 'account_status.dart';
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
    this.estadoCuenta = AccountStatus.aprobado,
    this.aldeaSolicitada = '',
    this.aprobadoPor,
    this.aprobadoEn,
    this.puedeVerIdentidad = false,
    this.contactosConfianza = const [],
  });

  final String id;
  final String nombre;
  final String telefono;
  final String? email;
  final UserRole rol;
  final String aldea;
  final bool activo;

  // ── R1: aprobación y roles no automáticos ──
  /// Estado de aprobación. Toda cuenta nueva nace [AccountStatus.pendienteRevision].
  final AccountStatus estadoCuenta;

  /// Aldea que el ciudadano declara al registrarse (la confirma la autoridad).
  final String aldeaSolicitada;

  /// uid de la autoridad que aprobó/asignó el rol.
  final String? aprobadoPor;

  /// Momento de la aprobación.
  final DateTime? aprobadoEn;

  /// R2: capacidad de ver las fotos del DPI de otros usuarios. La otorga la
  /// Municipalidad a verificadores concretos (mínimo privilegio).
  final bool puedeVerIdentidad;

  /// RF-11: uids de los contactos de confianza cuyas alertas SOS deben hacer
  /// sonar la alarma en el teléfono de este usuario. Los asigna una autoridad
  /// (COCODE/Municipalidad), no el propio ciudadano.
  final List<String> contactosConfianza;

  /// Solo las cuentas aprobadas y activas acceden a funciones sensibles.
  bool get puedeAcceder => activo && estadoCuenta.puedeAcceder;

  AppUser copyWith({
    String? nombre,
    String? telefono,
    String? email,
    UserRole? rol,
    String? aldea,
    bool? activo,
    AccountStatus? estadoCuenta,
    String? aldeaSolicitada,
    String? aprobadoPor,
    DateTime? aprobadoEn,
    bool? puedeVerIdentidad,
    List<String>? contactosConfianza,
  }) =>
      AppUser(
        id: id,
        nombre: nombre ?? this.nombre,
        telefono: telefono ?? this.telefono,
        email: email ?? this.email,
        rol: rol ?? this.rol,
        aldea: aldea ?? this.aldea,
        activo: activo ?? this.activo,
        estadoCuenta: estadoCuenta ?? this.estadoCuenta,
        aldeaSolicitada: aldeaSolicitada ?? this.aldeaSolicitada,
        aprobadoPor: aprobadoPor ?? this.aprobadoPor,
        aprobadoEn: aprobadoEn ?? this.aprobadoEn,
        puedeVerIdentidad: puedeVerIdentidad ?? this.puedeVerIdentidad,
        contactosConfianza: contactosConfianza ?? this.contactosConfianza,
      );

  @override
  List<Object?> get props => [
        id,
        nombre,
        telefono,
        email,
        rol,
        aldea,
        activo,
        estadoCuenta,
        aldeaSolicitada,
        aprobadoPor,
        aprobadoEn,
        puedeVerIdentidad,
        contactosConfianza,
      ];
}
