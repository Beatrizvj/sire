import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
        'nombreUsuario': _auth.currentUser?.displayName ?? '',
        // Aldea registrada del ciudadano: rutea la alerta a su COCODE (la
        // Municipalidad ve todas; cada COCODE, solo su aldea).
        'aldea': alert.aldea ?? '',
        'fecha': Timestamp.fromDate(alert.timestamp),
        'latitud': alert.latitude,
        'longitud': alert.longitude,
        'estado': alert.status.value,
        'tipo': alert.type,
        'origen': alert.source.name,
        'direccion': alert.address,
        'precision': alert.accuracy,
        'categoria': alert.categoria,
        'atendidaEn': alert.atendidaEn == null
            ? null
            : Timestamp.fromDate(alert.atendidaEn!),
        'resueltaEn': alert.resueltaEn == null
            ? null
            : Timestamp.fromDate(alert.resueltaEn!),
        'creadoEn': FieldValue.serverTimestamp(),
      };

  SosAlert _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final fecha = data['fecha'];
    return SosAlert(
      id: doc.id,
      userId: data['idUsuario'] as String?,
      userName: data['nombreUsuario'] as String?,
      aldea: data['aldea'] as String?,
      latitude: (data['latitud'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitud'] as num?)?.toDouble() ?? 0.0,
      timestamp: fecha is Timestamp ? fecha.toDate() : DateTime.now(),
      source: SosSource.values.firstWhere(
        (s) => s.name == data['origen'],
        orElse: () => SosSource.screenButton,
      ),
      status: AlertStatus.fromValue(data['estado'] as String? ?? 'pendiente'),
      type: data['tipo'] as String? ?? 'SOS',
      address: data['direccion'] as String?,
      accuracy: (data['precision'] as num?)?.toDouble(),
      categoria: data['categoria'] as String?,
      atendidaEn: (data['atendidaEn'] as Timestamp?)?.toDate(),
      resueltaEn: (data['resueltaEn'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Future<List<SosAlert>> getAlerts() async {
    final uid = _uid;
    if (uid == null) return const [];
    // Sin orderBy en el servidor para NO requerir un índice compuesto
    // (idUsuario + fecha). Se ordena en el cliente por fecha descendente.
    final snapshot =
        await _alertas.where('idUsuario', isEqualTo: uid).get();
    final alertas = snapshot.docs.map(_fromDoc).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return alertas;
  }

  @override
  Future<void> saveAlert(SosAlert alert) =>
      _alertas.doc(_buildDocId(alert.timestamp)).set(_toFirestore(alert));

  /// ID legible y ordenable por fecha: p. ej. 20260722-065701-3f2a.
  String _buildDocId(DateTime when) {
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(when);
    final suffix = (Random().nextInt(9000) + 1000).toString();
    return '$stamp-$suffix';
  }

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

  // Tope de alertas que se transmiten en vivo a la Bandeja/Mapa. Acota la carga
  // del hilo principal y el uso de datos: en vez de traer TODA la colección
  // (que crece sin límite), se escuchan solo las más recientes. Suficiente para
  // la operación diaria; el histórico completo no necesita estar en memoria.
  static const int _limiteAlertasEnVivo = 200;

  @override
  Stream<List<SosAlert>> watchAllAlerts() => _alertas
      .orderBy('fecha', descending: true)
      .limit(_limiteAlertasEnVivo)
      .snapshots()
      .map((snap) => snap.docs.map(_fromDoc).toList(growable: false));

  @override
  Stream<List<SosAlert>> watchAlertsByAldea(String aldea) =>
      _alertas.where('aldea', isEqualTo: aldea).snapshots().map((snap) {
        // Sin orderBy en el servidor para NO exigir un índice compuesto
        // (aldea + fecha). Se ordena en el cliente por fecha descendente.
        return snap.docs.map(_fromDoc).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      });

  @override
  Future<void> updateStatus(String id, AlertStatus status) {
    final data = <String, dynamic>{'estado': status.value};
    // Marca de tiempo para medir el tiempo de respuesta (la fija el servidor).
    if (status == AlertStatus.atendida) {
      data['atendidaEn'] = FieldValue.serverTimestamp();
    } else if (status == AlertStatus.resuelta) {
      data['resueltaEn'] = FieldValue.serverTimestamp();
    }
    return _alertas.doc(id).update(data);
  }

  @override
  Future<void> updateCategoria(String id, String categoria) =>
      _alertas.doc(id).update({'categoria': categoria});
}
