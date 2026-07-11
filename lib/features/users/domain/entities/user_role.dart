/// Roles de SIRE (campo `rol` en Firestore).
enum UserRole {
  ciudadano,
  cocode,
  monitor,
  administrador,
  superAdmin;

  String get value => switch (this) {
        UserRole.ciudadano => 'ciudadano',
        UserRole.cocode => 'cocode',
        UserRole.monitor => 'monitor',
        UserRole.administrador => 'administrador',
        UserRole.superAdmin => 'super_admin',
      };

  String get label => switch (this) {
        UserRole.ciudadano => 'Ciudadano',
        UserRole.cocode => 'COCODE',
        UserRole.monitor => 'Monitor',
        UserRole.administrador => 'Administrador',
        UserRole.superAdmin => 'Super Admin',
      };

  static UserRole fromValue(String value) => UserRole.values.firstWhere(
        (role) => role.value == value,
        orElse: () => UserRole.ciudadano,
      );
}
