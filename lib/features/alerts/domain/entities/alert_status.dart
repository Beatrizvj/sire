/// Estado de una alerta (campo `estado` en Firestore).
enum AlertStatus {
  pendiente,
  atendida,
  resuelta,
  falsaAlarma;

  /// Valor persistido (Firestore / JSON).
  String get value => switch (this) {
        AlertStatus.pendiente => 'pendiente',
        AlertStatus.atendida => 'atendida',
        AlertStatus.resuelta => 'resuelta',
        AlertStatus.falsaAlarma => 'falsa_alarma',
      };

  String get label => switch (this) {
        AlertStatus.pendiente => 'Pendiente',
        AlertStatus.atendida => 'Atendida',
        AlertStatus.resuelta => 'Resuelta',
        AlertStatus.falsaAlarma => 'Falsa alarma',
      };

  static AlertStatus fromValue(String value) => AlertStatus.values.firstWhere(
        (status) => status.value == value,
        orElse: () => AlertStatus.pendiente,
      );
}
