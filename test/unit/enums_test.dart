import 'package:flutter_test/flutter_test.dart';
import 'package:sire/features/alerts/domain/entities/alert_status.dart';
import 'package:sire/features/alerts/domain/entities/sos_source.dart';
import 'package:sire/features/users/domain/entities/account_status.dart';
import 'package:sire/features/users/domain/entities/user_role.dart';

/// Pruebas de los enums de dominio y sus conversiones tolerantes usadas al
/// leer/escribir Firestore. Lógica pura.
void main() {
  group('UserRole', () {
    test('value y label', () {
      expect(UserRole.cocode.value, 'cocode');
      expect(UserRole.municipalidad.label, 'Municipalidad');
      expect(UserRole.ciudadano.value, 'ciudadano');
    });

    test('fromValue es tolerante a mayúsculas/espacios', () {
      expect(UserRole.fromValue('COCODE '), UserRole.cocode);
      expect(UserRole.fromValue('  Municipalidad'), UserRole.municipalidad);
    });

    test('fromValue con valor desconocido cae en ciudadano', () {
      expect(UserRole.fromValue('desconocido'), UserRole.ciudadano);
    });
  });

  group('AccountStatus', () {
    test('nulo o vacío => aprobado (compatibilidad con docs antiguos)', () {
      expect(AccountStatus.fromValue(null), AccountStatus.aprobado);
      expect(AccountStatus.fromValue(''), AccountStatus.aprobado);
    });

    test('valor desconocido no vacío => pendienteRevision (por prudencia)', () {
      expect(AccountStatus.fromValue('???'), AccountStatus.pendienteRevision);
    });

    test('mapea los valores conocidos', () {
      expect(AccountStatus.fromValue('pendiente_revision'),
          AccountStatus.pendienteRevision);
      expect(AccountStatus.fromValue('aprobado'), AccountStatus.aprobado);
      expect(AccountStatus.fromValue('rechazado'), AccountStatus.rechazado);
    });

    test('puedeAcceder solo si está aprobado', () {
      expect(AccountStatus.aprobado.puedeAcceder, isTrue);
      expect(AccountStatus.pendienteRevision.puedeAcceder, isFalse);
      expect(AccountStatus.rechazado.puedeAcceder, isFalse);
      expect(AccountStatus.suspendido.puedeAcceder, isFalse);
    });
  });

  group('AlertStatus', () {
    test('round-trip value <-> fromValue', () {
      for (final s in AlertStatus.values) {
        expect(AlertStatus.fromValue(s.value), s);
      }
    });

    test('mapea falsa_alarma y usa pendiente como fallback', () {
      expect(AlertStatus.fromValue('falsa_alarma'), AlertStatus.falsaAlarma);
      expect(AlertStatus.fromValue('xxx'), AlertStatus.pendiente);
    });
  });

  group('SosSource', () {
    test('name persistido y etiqueta legible', () {
      expect(SosSource.screenButton.name, 'screenButton');
      expect(SosSource.powerButton.name, 'powerButton');
      expect(SosSource.powerButton.label, contains('encendido'));
    });
  });
}
