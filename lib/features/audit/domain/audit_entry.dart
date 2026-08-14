/// Registro de auditoría (R1): bitácora inmutable de una acción sensible.
///
/// Responde "quién hizo qué, cuándo y sobre quién". Solo se crea; nunca se
/// edita ni se borra (las reglas de seguridad lo garantizan).
class AuditEntry {
  const AuditEntry({
    required this.accion,
    required this.actorUid,
    required this.actorRol,
    required this.objetivoUid,
    this.objetivoNombre = '',
    this.valorAnterior,
    this.valorNuevo,
    this.detalle,
    this.fechaHora,
  });

  /// Acción ejecutada: 'aprobar_usuario' | 'rechazar_usuario' | 'cambiar_rol' | …
  final String accion;
  final String actorUid;
  final String actorRol;
  final String objetivoUid;
  final String objetivoNombre;

  /// Estado antes/después, p. ej. {'rol': 'ciudadano', 'estado': 'pendiente_revision'}.
  final Map<String, dynamic>? valorAnterior;
  final Map<String, dynamic>? valorNuevo;

  /// Texto libre (motivo de rechazo, etc.).
  final String? detalle;

  /// Se llena en el servidor (serverTimestamp) al escribir.
  final DateTime? fechaHora;
}
