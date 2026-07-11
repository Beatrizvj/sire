import 'dart:convert';

import '../../domain/entities/sos_alert.dart';
import '../../domain/entities/sos_source.dart';

/// Serialización de [SosAlert] hacia/desde JSON (shared_preferences).
///
/// El mismo mapa servirá de base para el documento de Firestore en el Hito 3.
class SosAlertModel {
  const SosAlertModel._();

  static Map<String, dynamic> toMap(SosAlert alert) => {
        'id': alert.id,
        'latitude': alert.latitude,
        'longitude': alert.longitude,
        'timestamp': alert.timestamp.toIso8601String(),
        'source': alert.source.name,
        'address': alert.address,
        'accuracy': alert.accuracy,
      };

  static SosAlert fromMap(Map<String, dynamic> map) => SosAlert(
        id: map['id'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        timestamp: DateTime.parse(map['timestamp'] as String),
        source: SosSource.values.byName(map['source'] as String),
        address: map['address'] as String?,
        accuracy: (map['accuracy'] as num?)?.toDouble(),
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
