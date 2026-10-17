import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../audit/data/audit_repository.dart';
import '../../../audit/domain/audit_entry.dart';
import '../../domain/entities/account_status.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/permisos.dart';
import 'users_providers.dart';

/// Servicio de aprobación de usuarios (R1). Compone el repositorio de usuarios
/// con la auditoría: cada aprobación/rechazo queda registrado (quién, cuándo).
class ApprovalsService {
  ApprovalsService(this._ref);

  final Ref _ref;

  /// Aprueba una cuenta: le asigna rol y aldea y la marca aprobada; el servidor
  /// registra en la bitácora quién lo hizo. [actor] es la autoridad que aprueba.
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
    // La bitácora la escribe el servidor (functions/bitacora.js).
    await _ref.read(userRepositoryProvider).saveUser(actualizado);
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
          actorNombre: actor.nombre,
          actorCoordinador: actor.esCoordinador,
          aldea: objetivo.aldeaSolicitada,
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

/// Roles que [actor] puede asignar al aprobar una cuenta (mínimo privilegio):
/// - Municipalidad: cualquiera.
/// - Coordinador del COCODE o de la Alcaldía Auxiliar: integrante de su propio
///   cuerpo (primero, por defecto) o ciudadano.
/// - Aprobador delegado: solo ciudadano.
List<UserRole> rolesAsignablesPor(AppUser actor) {
  if (actor.rol == UserRole.municipalidad) return UserRole.values;
  if (actor.esCoordinador) return [actor.rol, UserRole.ciudadano];
  return const [UserRole.ciudadano];
}

/// Usuarios pendientes de revisión que le corresponden a [autoridad]:
/// - Municipalidad: todos los pendientes del municipio.
/// - Coordinador o aprobador delegado: los que declararon su misma aldea.
/// - Demás integrantes: ninguno (no aprueban cuentas).
List<AppUser> pendientesPara(List<AppUser> todos, AppUser autoridad) {
  if (!autoridad.puedeAprobarCuentas) return const [];
  final pendientes = todos
      .where((u) => u.estadoCuenta == AccountStatus.pendienteRevision)
      .toList();
  if (autoridad.rol == UserRole.municipalidad) return pendientes;
  return pendientes
      .where((u) =>
          u.aldeaSolicitada.trim().toLowerCase() ==
          autoridad.aldea.trim().toLowerCase())
      .toList();
}
