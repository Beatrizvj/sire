import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/firestore_collections.dart';
import '../domain/audit_entry.dart';

/// Escribe registros de auditoría (R1). Colección `auditoria`, solo-inserción.
abstract interface class AuditRepository {
  Future<void> registrar(AuditEntry entry);

  /// Bitácora de [aldea] (vacía = todo el municipio, solo Municipalidad), de
  /// la más reciente a la más antigua.
  Stream<List<AuditEntry>> watchBitacora({String aldea = ''});

  /// Historial de una alerta. [aldea] filtra para las autoridades de aldea
  /// (vacía = Municipalidad).
  Stream<List<AuditEntry>> watchHistorialAlerta(String alertaId,
      {String aldea = ''});
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
      'objetivoTipo': entry.objetivoTipo,
      'actorNombre': entry.actorNombre,
      'actorCoordinador': entry.actorCoordinador,
      'aldea': entry.aldea,
      'valorAnterior': entry.valorAnterior,
      'valorNuevo': entry.valorNuevo,
      'detalle': entry.detalle,
      // La hora la fija el servidor, no el cliente (no se puede falsear).
      'fechaHora': FieldValue.serverTimestamp(),
    });
  }

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirestoreCollections.auditoria);

  static AuditEntry _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    Map<String, dynamic>? mapa(Object? v) =>
        v is Map ? Map<String, dynamic>.from(v) : null;
    return AuditEntry(
      id: d.id,
      accion: m['accion'] as String? ?? '',
      actorUid: m['actorUid'] as String? ?? '',
      actorNombre: m['actorNombre'] as String? ?? '',
      actorRol: m['actorRol'] as String? ?? '',
      actorCoordinador: m['actorCoordinador'] == true,
      objetivoUid: m['objetivoUid'] as String? ?? '',
      objetivoNombre: m['objetivoNombre'] as String? ?? '',
      objetivoTipo: m['objetivoTipo'] as String? ?? 'usuario',
      aldea: m['aldea'] as String? ?? '',
      valorAnterior: mapa(m['valorAnterior']),
      valorNuevo: mapa(m['valorNuevo']),
      detalle: m['detalle'] as String?,
      fechaHora: (m['fechaHora'] as Timestamp?)?.toDate(),
    );
  }

  /// Sin orderBy en el servidor para no exigir índices compuestos: se ordena
  /// en el cliente (los recién escritos, aún sin hora, primero).
  static List<AuditEntry> _ordenar(QuerySnapshot<Map<String, dynamic>> snap) =>
      snap.docs.map(_fromDoc).toList()
        ..sort((a, b) => (b.fechaHora ?? DateTime(9999))
            .compareTo(a.fechaHora ?? DateTime(9999)));

  @override
  Stream<List<AuditEntry>> watchBitacora({String aldea = ''}) {
    if (aldea.isEmpty) {
      return _col
          .orderBy('fechaHora', descending: true)
          .limit(500)
          .snapshots()
          .map(_ordenar);
    }
    return _col.where('aldea', isEqualTo: aldea).snapshots().map(_ordenar);
  }

  @override
  Stream<List<AuditEntry>> watchHistorialAlerta(String alertaId,
      {String aldea = ''}) {
    var q = _col
        .where('objetivoUid', isEqualTo: alertaId)
        .where('objetivoTipo', isEqualTo: 'alerta');
    if (aldea.isNotEmpty) q = q.where('aldea', isEqualTo: aldea);
    return q.snapshots().map(_ordenar);
  }
}

/// En modo demo local no hay backend de auditoría: no-op silencioso.
class AuditRepositoryLocal implements AuditRepository {
  const AuditRepositoryLocal();

  @override
  Future<void> registrar(AuditEntry entry) async {}

  @override
  Stream<List<AuditEntry>> watchBitacora({String aldea = ''}) =>
      Stream.value(const []);

  @override
  Stream<List<AuditEntry>> watchHistorialAlerta(String alertaId,
          {String aldea = ''}) =>
      Stream.value(const []);
}

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  if (AppConfig.firebaseEnabled) {
    return AuditRepositoryFirestore(FirebaseFirestore.instance);
  }
  return const AuditRepositoryLocal();
});
