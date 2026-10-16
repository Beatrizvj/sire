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
    this.objetivoTipo = 'usuario',
    this.actorNombre = '',
    this.actorCoordinador = false,
    this.aldea = '',
    this.id = '',
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

  /// 'alerta' | 'usuario'.
  final String objetivoTipo;
  final String actorNombre;
  final bool actorCoordinador;

  /// Aldea a la que pertenece el registro (define quién puede leerlo).
  final String aldea;

  /// Id del documento (solo al leer).
  final String id;

  /// Estado antes/después, p. ej. {'rol': 'ciudadano', 'estado': 'pendiente_revision'}.
  final Map<String, dynamic>? valorAnterior;
  final Map<String, dynamic>? valorNuevo;

  /// Texto libre (motivo de rechazo, etc.).
  final String? detalle;

  /// Se llena en el servidor (serverTimestamp) al escribir.
  final DateTime? fechaHora;
}

/// Texto legible de cada acción de la bitácora.
String descripcionAccion(String accion) => switch (accion) {
      'atender_alerta' => 'Atendió la alerta',
      'resolver_alerta' => 'Resolvió la alerta',
      'falsa_alarma' => 'Marcó la alerta como falsa alarma',
      'reabrir_alerta' => 'Reabrió la alerta',
      'cambiar_estado_alerta' => 'Cambió el estado de la alerta',
      'clasificar_alerta' => 'Clasificó el incidente',
      'aprobar_usuario' => 'Aprobó la cuenta',
      'rechazar_usuario' => 'Rechazó la solicitud',
      'suspender_usuario' => 'Suspendió la cuenta',
      'reactivar_usuario' => 'Reactivó la cuenta',
      'cambiar_estado_cuenta' => 'Cambió el estado de la cuenta',
      'designar_coordinador' => 'Designó como coordinador',
      'quitar_coordinador' => 'Quitó la coordinación',
      'delegar_aprobacion' => 'Delegó la aprobación de cuentas',
      'quitar_aprobacion' => 'Quitó la aprobación de cuentas',
      'cambiar_rol' => 'Cambió el rol',
      'cambiar_contactos_confianza' => 'Cambió los contactos de confianza',
      'cambiar_aldea' => 'Cambió la aldea',
      'corregir_nombre' => 'Corrigió el nombre',
      'eliminar_usuario' => 'Eliminó al usuario',
      'ver_foto_id' => 'Vio las fotos del DPI',
      _ => accion,
    };
