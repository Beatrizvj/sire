import 'package:flutter_test/flutter_test.dart';
import 'package:sire/features/alerts/domain/entities/alert_status.dart';
import 'package:sire/features/alerts/domain/entities/sos_alert.dart';
import 'package:sire/features/alerts/domain/entities/sos_source.dart';

SosAlert _alerta({DateTime? timestamp, DateTime? atendidaEn}) => SosAlert(
      id: 'a1',
      latitude: 14.87,
      longitude: -91.60,
      timestamp: timestamp ?? DateTime(2026, 9, 8, 10, 0, 0),
      source: SosSource.screenButton,
      atendidaEn: atendidaEn,
    );

/// Pruebas de la entidad de alerta y el formateo del tiempo de respuesta
/// (indicador clave de los reportes/BI). Lógica pura.
void main() {
  group('SosAlert.tiempoRespuesta', () {
    test('es null mientras la alerta no ha sido atendida', () {
      expect(_alerta().tiempoRespuesta, isNull);
    });

    test('es la diferencia entre atendidaEn y la creación', () {
      final a = _alerta(
        timestamp: DateTime(2026, 9, 8, 10, 0, 0),
        atendidaEn: DateTime(2026, 9, 8, 10, 3, 20),
      );
      expect(a.tiempoRespuesta, const Duration(minutes: 3, seconds: 20));
    });
  });

  group('SosAlert.copyWith', () {
    test('cambia el estado y conserva el resto de campos', () {
      final a = _alerta();
      final b = a.copyWith(status: AlertStatus.atendida);
      expect(b.status, AlertStatus.atendida);
      expect(b.id, a.id);
      expect(b.latitude, a.latitude);
      expect(b.longitude, a.longitude);
      expect(b.source, a.source);
    });
  });

  group('formatearDuracion', () {
    test('segundos', () {
      expect(formatearDuracion(const Duration(seconds: 45)), '45 s');
    });
    test('minutos y segundos', () {
      expect(formatearDuracion(const Duration(minutes: 3, seconds: 20)),
          '3 min 20 s');
    });
    test('minutos exactos', () {
      expect(formatearDuracion(const Duration(minutes: 2)), '2 min');
    });
    test('horas exactas', () {
      expect(formatearDuracion(const Duration(hours: 1)), '1 h');
    });
    test('horas y minutos', () {
      expect(formatearDuracion(const Duration(hours: 1, minutes: 1)),
          '1 h 1 min');
    });
  });
}
