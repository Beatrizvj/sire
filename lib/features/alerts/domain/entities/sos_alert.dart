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
    this.atendidaPor,
    this.atendidaPorNombre,
    this.latitudActual,
    this.longitudActual,
    this.precisionActual,
    this.ubicacionActualEn,
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

  /// Trazabilidad de la atención: autoridad (COCODE/Municipalidad) que marcó la
  /// alerta como "atendida". [atendidaPor] es su uid; [atendidaPorNombre] su
  /// nombre, guardado de forma denormalizada para mostrarlo sin otra consulta.
  final String? atendidaPor;
  final String? atendidaPorNombre;

  /// Tiempo de respuesta = desde que se creó la alerta hasta que se atendió.
  /// Ubicación EN VIVO: la última que mandó el teléfono del ciudadano mientras
  /// la alerta sigue abierta (null si aún no hay seguimiento).
  final double? latitudActual;
  final double? longitudActual;
  final double? precisionActual;
  final DateTime? ubicacionActualEn;

  /// Hay seguimiento en vivo.
  bool get tieneUbicacionEnVivo =>
      latitudActual != null && longitudActual != null;

  /// Dónde está la persona AHORA: la ubicación en vivo si existe; si no, la
  /// del momento del SOS. Para llegar a ella (mapa, "Cómo llegar").
  double get latitudParaLlegar => latitudActual ?? latitude;
  double get longitudParaLlegar => longitudActual ?? longitude;

  /// Hay algún punto al que llegar.
  bool get tieneUbicacionParaLlegar => tieneUbicacionEnVivo || tieneUbicacion;

  /// La alerta sigue abierta (el teléfono puede estar compartiendo).
  bool get sigueAbierta =>
      status == AlertStatus.pendiente || status == AlertStatus.atendida;

  Duration? get tiempoRespuesta => atendidaEn?.difference(timestamp);

  /// La alerta trae una ubicación real. 0,0 es el valor centinela para "sin
  /// ubicación" (GPS apagado y sin última conocida), igual que el botón físico.
  bool get tieneUbicacion => latitude != 0 || longitude != 0;

  SosAlert copyWith({
    AlertStatus? status,
    String? categoria,
    DateTime? atendidaEn,
    DateTime? resueltaEn,
    String? atendidaPor,
    String? atendidaPorNombre,
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
        atendidaPor: atendidaPor ?? this.atendidaPor,
        atendidaPorNombre: atendidaPorNombre ?? this.atendidaPorNombre,
        latitudActual: latitudActual,
        longitudActual: longitudActual,
        precisionActual: precisionActual,
        ubicacionActualEn: ubicacionActualEn,
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
        atendidaPor,
        atendidaPorNombre,
        latitudActual,
        longitudActual,
        precisionActual,
        ubicacionActualEn,
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

/// "hace 8 s", "hace 3 min", "hace 2 h" (antigüedad de la ubicación en vivo).
String haceCuanto(DateTime t, {DateTime? ahora}) {
  final d = (ahora ?? DateTime.now()).difference(t);
  if (d.inSeconds < 60) return 'hace ${d.inSeconds < 0 ? 0 : d.inSeconds} s';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  return 'hace ${d.inHours} h';
}
