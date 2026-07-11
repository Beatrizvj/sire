import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/config/firestore_collections.dart';
import '../../domain/entities/alert_status.dart';
import '../../domain/entities/sos_alert.dart';
import '../../domain/entities/sos_source.dart';
import '../../domain/repositories/alert_repository.dart';

/// Implementación de [AlertRepository] con Cloud Firestore (colección `alertas`).
///
/// Mapea al esquema de la tesis: `idUsuario`, `fecha`, `latitud`, `longitud`,
/// `estado`, `tipo`.
class AlertRepositoryFirestore implements AlertRepository {
  AlertRepositoryFirestore(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _alertas =>
      _firestore.collection(FirestoreCollections.alertas);

  String? get _uid => _auth.currentUser?.uid;

  Map<String, dynamic> _toFirestore(SosAlert alert) => {
        'idUsuario': alert.userId ?? _uid,
        'fecha': Timestamp.fromDate(alert.timestamp),
        'latitud': alert.latitude,
        'longitud': alert.longitude,
        'estado': alert.status.value,
        'tipo': alert.type,
        'origen': alert.source.name,
        'direccion': alert.address,
        'precision': alert.accuracy,
        'creadoEn': FieldValue.serverTimestamp(),
      };

  SosAlert _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final fecha = data['fecha'];
    return SosAlert(
      id: doc.id,
      userId: data['idUsuario'] as String?,
      latitude: (data['latitud'] as num).toDouble(),
      longitude: (data['longitud'] as num).toDouble(),
      timestamp: fecha is Timestamp ? fecha.toDate() : DateTime.now(),
      source: SosSource.values.firstWhere(
        (s) => s.name == data['origen'],
        orElse: () => SosSource.screenButton,
      ),
      status: AlertStatus.fromValue(data['estado'] as String? ?? 'pendiente'),
      type: data['tipo'] as String? ?? 'SOS',
      address: data['direccion'] as String?,
      accuracy: (data['precision'] as num?)?.toDouble(),
    );
  }

  @override
  Future<List<SosAlert>> getAlerts() async {
    final uid = _uid;
    if (uid == null) return const [];
    final snapshot = await _alertas
        .where('idUsuario', isEqualTo: uid)
        .orderBy('fecha', descending: true)
        .get();
    return snapshot.docs.map(_fromDoc).toList(growable: false);
  }

  @override
  Future<void> saveAlert(SosAlert alert) => _alertas.add(_toFirestore(alert));

  @override
  Future<void> clear() async {
    final uid = _uid;
    if (uid == null) return;
    final snapshot = await _alertas.where('idUsuario', isEqualTo: uid).get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
