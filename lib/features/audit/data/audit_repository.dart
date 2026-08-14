import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/firestore_collections.dart';
import '../domain/audit_entry.dart';

/// Escribe registros de auditoría (R1). Colección `auditoria`, solo-inserción.
abstract interface class AuditRepository {
  Future<void> registrar(AuditEntry entry);
}

class AuditRepositoryFirestore implements AuditRepository {
  AuditRepositoryFirestore(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<void> registrar(AuditEntry entry) async {
    await _firestore.collection(FirestoreCollections.auditoria).add({
      'accion': entry.accion,
      'actorUid': entry.actorUid,
      'actorRol': entry.actorRol,
      'objetivoUid': entry.objetivoUid,
      'objetivoNombre': entry.objetivoNombre,
      'valorAnterior': entry.valorAnterior,
      'valorNuevo': entry.valorNuevo,
      'detalle': entry.detalle,
      // La hora la fija el servidor, no el cliente (no se puede falsear).
      'fechaHora': FieldValue.serverTimestamp(),
    });
  }
}

/// En modo demo local no hay backend de auditoría: no-op silencioso.
class AuditRepositoryLocal implements AuditRepository {
  const AuditRepositoryLocal();

  @override
  Future<void> registrar(AuditEntry entry) async {}
}

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  if (AppConfig.firebaseEnabled) {
    return AuditRepositoryFirestore(FirebaseFirestore.instance);
  }
  return const AuditRepositoryLocal();
});
