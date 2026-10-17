/// Roles de SIRE (campo `rol` en Firestore).
///
/// Vocabulario oficial de la tesis: Ciudadano, COCODE, Alcaldía Auxiliar y
/// Municipalidad. La Alcaldía Auxiliar tiene los mismos permisos que el COCODE,
/// limitados a SU aldea.
enum UserRole {
  ciudadano,
  cocode,
  auxiliatura,
  municipalidad;

  String get value => switch (this) {
        UserRole.ciudadano => 'ciudadano',
        UserRole.cocode => 'cocode',
        UserRole.auxiliatura => 'auxiliatura',
        UserRole.municipalidad => 'municipalidad',
      };

  String get label => switch (this) {
        UserRole.ciudadano => 'Ciudadano',
        UserRole.cocode => 'COCODE',
        UserRole.auxiliatura => 'Alcaldía Auxiliar',
        UserRole.municipalidad => 'Municipalidad',
      };

  /// Autoridad de UNA aldea (COCODE o Alcaldía Auxiliar): ve, atiende y
  /// gestiona solo lo de su aldea.
  bool get esAutoridadDeAldea =>
      this == UserRole.cocode || this == UserRole.auxiliatura;

  /// Cualquier autoridad (de aldea o Municipalidad).
  bool get esAutoridad => esAutoridadDeAldea || this == UserRole.municipalidad;

  static UserRole fromValue(String value) {
    // Tolerante a mayúsculas/espacios: "Cocode", "COCODE " → cocode.
    final v = value.trim().toLowerCase();
    return UserRole.values.firstWhere(
      (role) => role.value == v,
      orElse: () => UserRole.ciudadano,
    );
  }
}
