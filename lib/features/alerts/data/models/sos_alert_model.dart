import 'dart:convert';

import '../../domain/entities/alert_status.dart';
import '../../domain/entities/sos_alert.dart';
import '../../domain/entities/sos_source.dart';

/// Serialización de [SosAlert] hacia/desde JSON (shared_preferences).
///
/// La conversión específica de Firestore (Timestamp, nombres `idUsuario`,
/// `estado`, `tipo`…) vive en `AlertRepositoryFirestore`.
class SosAlertModel {
  const SosAlertModel._();

  static Map<String, dynamic> toMap(SosAlert alert) => {
        'id': alert.id,
        'userId': alert.userId,
        'userName': alert.userName,
        'latitude': alert.latitude,
        'longitude': alert.longitude,
        'timestamp': alert.timestamp.toIso8601String(),
        'source': alert.source.name,
        'status': alert.status.value,
        'type': alert.type,
        'address': alert.address,
        'accuracy': alert.accuracy,
        'categoria': alert.categoria,
      };

  static SosAlert fromMap(Map<String, dynamic> map) => SosAlert(
        id: map['id'] as String,
        userId: map['userId'] as String?,
        userName: map['userName'] as String?,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        timestamp: DateTime.parse(map['timestamp'] as String),
        source: SosSource.values.byName(map['source'] as String),
        status: AlertStatus.fromValue(map['status'] as String? ?? 'pendiente'),
        type: map['type'] as String? ?? 'SOS',
        address: map['address'] as String?,
        accuracy: (map['accuracy'] as num?)?.toDouble(),
        categoria: map['categoria'] as String?,
      );

  static String encodeList(List<SosAlert> alerts) =>
      jsonEncode(alerts.map(toMap).toList());

  static List<SosAlert> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => fromMap(e as Map<String, dynamic>))
        .toList(growable: false);
  }
}
