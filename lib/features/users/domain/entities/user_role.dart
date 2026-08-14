/// Roles de SIRE (campo `rol` en Firestore).
///
/// Vocabulario oficial de la tesis: Ciudadano, COCODE y Municipalidad.
enum UserRole {
  ciudadano,
  cocode,
  municipalidad;

  String get value => switch (this) {
        UserRole.ciudadano => 'ciudadano',
        UserRole.cocode => 'cocode',
        UserRole.municipalidad => 'municipalidad',
      };

  String get label => switch (this) {
        UserRole.ciudadano => 'Ciudadano',
        UserRole.cocode => 'COCODE',
        UserRole.municipalidad => 'Municipalidad',
      };

  static UserRole fromValue(String value) {
    // Tolerante a mayúsculas/espacios: "Cocode", "COCODE " → cocode.
    final v = value.trim().toLowerCase();
    return UserRole.values.firstWhere(
      (role) => role.value == v,
      orElse: () => UserRole.ciudadano,
    );
  }
}
