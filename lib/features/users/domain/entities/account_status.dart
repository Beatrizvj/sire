/// Estado de aprobación de una cuenta (campo `estadoCuenta` en Firestore).
///
/// Requisito R1: el rol NO se asigna automáticamente. Toda cuenta nueva nace en
/// [pendienteRevision] y solo una autoridad (COCODE de la aldea o Municipalidad)
/// puede pasarla a [aprobado] asignándole un rol.
enum AccountStatus {
  pendienteRevision,
  aprobado,
  rechazado,
  suspendido;

  String get value => switch (this) {
        AccountStatus.pendienteRevision => 'pendiente_revision',
        AccountStatus.aprobado => 'aprobado',
        AccountStatus.rechazado => 'rechazado',
        AccountStatus.suspendido => 'suspendido',
      };

  String get label => switch (this) {
        AccountStatus.pendienteRevision => 'Pendiente de revisión',
        AccountStatus.aprobado => 'Aprobado',
        AccountStatus.rechazado => 'Rechazado',
        AccountStatus.suspendido => 'Suspendido',
      };

  /// Solo las cuentas aprobadas acceden a funciones sensibles.
  bool get puedeAcceder => this == AccountStatus.aprobado;

  /// Tolerante a mayúsculas/espacios. Los documentos antiguos que NO tienen el
  /// campo se consideran [aprobado] (usuarios existentes antes de R1: no se les
  /// bloquea el acceso). Por eso el fallback para valor nulo es [aprobado],
  /// pero un valor desconocido no vacío cae en [pendienteRevision] por prudencia.
  static AccountStatus fromValue(String? value) {
    if (value == null || value.trim().isEmpty) return AccountStatus.aprobado;
    final v = value.trim().toLowerCase();
    return AccountStatus.values.firstWhere(
      (s) => s.value == v,
      orElse: () => AccountStatus.pendienteRevision,
    );
  }
}
