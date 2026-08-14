import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../audit/data/audit_repository.dart';
import '../../../audit/domain/audit_entry.dart';
import '../../domain/entities/account_status.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import 'users_providers.dart';

/// Servicio de aprobación de usuarios (R1). Compone el repositorio de usuarios
/// con la auditoría: cada aprobación/rechazo queda registrado (quién, cuándo).
class ApprovalsService {
  ApprovalsService(this._ref);

  final Ref _ref;

  /// Aprueba una cuenta: le asigna rol y aldea, la marca aprobada y registra
  /// en auditoría quién lo hizo. [actor] es la autoridad que aprueba.
  Future<void> aprobar(
    AppUser objetivo, {
    required UserRole rol,
    required String aldea,
    required AppUser actor,
  }) async {
    final actualizado = objetivo.copyWith(
      rol: rol,
      aldea: aldea,
      estadoCuenta: AccountStatus.aprobado,
      aprobadoPor: actor.id,
      aprobadoEn: DateTime.now(),
    );
    await _ref.read(userRepositoryProvider).saveUser(actualizado);
    await _ref.read(auditRepositoryProvider).registrar(AuditEntry(
          accion: 'aprobar_usuario',
          actorUid: actor.id,
          actorRol: actor.rol.value,
          objetivoUid: objetivo.id,
          objetivoNombre: objetivo.nombre,
          valorAnterior: {
            'rol': objetivo.rol.value,
            'estado': objetivo.estadoCuenta.value,
          },
          valorNuevo: {'rol': rol.value, 'estado': AccountStatus.aprobado.value},
        ));
  }

  /// Rechaza una cuenta (con motivo) y lo registra en auditoría.
  Future<void> rechazar(
    AppUser objetivo, {
    required AppUser actor,
    String motivo = '',
  }) async {
    final actualizado =
        objetivo.copyWith(estadoCuenta: AccountStatus.rechazado);
    await _ref.read(userRepositoryProvider).saveUser(actualizado);
    await _ref.read(auditRepositoryProvider).registrar(AuditEntry(
          accion: 'rechazar_usuario',
          actorUid: actor.id,
          actorRol: actor.rol.value,
          objetivoUid: objetivo.id,
          objetivoNombre: objetivo.nombre,
          valorAnterior: {'estado': objetivo.estadoCuenta.value},
          valorNuevo: {'estado': AccountStatus.rechazado.value},
          detalle: motivo.isEmpty ? null : motivo,
        ));
  }
}

final approvalsServiceProvider =
    Provider<ApprovalsService>(ApprovalsService.new);

/// Usuarios pendientes de revisión que le corresponden a [autoridad]:
/// - Municipalidad: todos los pendientes del municipio.
/// - COCODE: solo los que declararon su misma aldea.
List<AppUser> pendientesPara(List<AppUser> todos, AppUser autoridad) {
  final pendientes = todos
      .where((u) => u.estadoCuenta == AccountStatus.pendienteRevision)
      .toList();
  if (autoridad.rol == UserRole.municipalidad) return pendientes;
  if (autoridad.rol == UserRole.cocode) {
    return pendientes
        .where((u) =>
            u.aldeaSolicitada.trim().toLowerCase() ==
            autoridad.aldea.trim().toLowerCase())
        .toList();
  }
  return const [];
}
