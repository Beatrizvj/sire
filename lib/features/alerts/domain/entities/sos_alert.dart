import 'package:equatable/equatable.dart';

import 'alert_status.dart';
import 'sos_source.dart';

/// Una alerta de emergencia (SOS) generada por el ciudadano.
///
/// Los campos mapean el esquema de Firestore de la tesis:
/// `idUsuario`, `fecha`, `latitud`, `longitud`, `estado`, `tipo`, `aldea`.
class SosAlert extends Equatable {
  const SosAlert({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.source,
    this.userId,
    this.userName,
    this.aldea,
    this.status = AlertStatus.pendiente,
    this.type = 'SOS',
    this.address,
    this.accuracy,
    this.categoria,
    this.atendidaEn,
    this.resueltaEn,
  });

  final String id;

  /// idUsuario (uid). Nulo en modo local sin sesión.
  final String? userId;

  /// Nombre del ciudadano (nombreUsuario), para que la autoridad lo identifique.
  final String? userName;

  /// Aldea REGISTRADA del ciudadano que envía el SOS. Rutea la alerta: la
  /// Municipalidad ve TODAS; cada COCODE, solo las de su aldea. Nula/"" = sin
  /// aldea asignada (solo la Municipalidad la atiende).
  final String? aldea;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final SosSource source;
  final AlertStatus status;
  final String type;

  /// Dirección aproximada (reverse geocoding); puede ser nula sin conexión.
  final String? address;

  /// Precisión del GPS en metros.
  final double? accuracy;

  /// R3: categoría del incidente (Robo, Asalto, Persona sospechosa). Nula =
  /// "sin especificar" (p. ej. SOS por botón de encendido, a clasificar después).
  final String? categoria;

  /// Tiempo de respuesta: momentos en que la autoridad marcó la alerta como
  /// "atendida" y "resuelta". Nulos hasta que ocurra cada transición.
  final DateTime? atendidaEn;
  final DateTime? resueltaEn;

  /// Tiempo de respuesta = desde que se creó la alerta hasta que se atendió.
  Duration? get tiempoRespuesta => atendidaEn?.difference(timestamp);

  SosAlert copyWith({
    AlertStatus? status,
    String? categoria,
    DateTime? atendidaEn,
    DateTime? resueltaEn,
  }) =>
      SosAlert(
        id: id,
        userId: userId,
        userName: userName,
        aldea: aldea,
        latitude: latitude,
        longitude: longitude,
        timestamp: timestamp,
        source: source,
        status: status ?? this.status,
        type: type,
        address: address,
        accuracy: accuracy,
        categoria: categoria ?? this.categoria,
        atendidaEn: atendidaEn ?? this.atendidaEn,
        resueltaEn: resueltaEn ?? this.resueltaEn,
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        userName,
        aldea,
        latitude,
        longitude,
        timestamp,
        source,
        status,
        type,
        address,
        accuracy,
        categoria,
        atendidaEn,
        resueltaEn,
      ];
}

/// Formatea una duración como "45 s", "3 min 20 s" o "2 h 5 min".
String formatearDuracion(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds} s';
  if (d.inMinutes < 60) {
    final s = d.inSeconds % 60;
    return s == 0 ? '${d.inMinutes} min' : '${d.inMinutes} min $s s';
  }
  final m = d.inMinutes % 60;
  return m == 0 ? '${d.inHours} h' : '${d.inHours} h $m min';
}
