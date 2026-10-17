import 'package:flutter_test/flutter_test.dart';
import 'package:sire/core/validation/name_validator.dart';
import 'package:sire/core/validation/password_validator.dart';

/// Pruebas de las validaciones de entrada (R4 / módulo de seguridad).
/// Son lógica pura: no requieren Firebase ni widgets.
void main() {
  group('NameValidator.validar', () {
    test('acepta nombres reales (con acentos, apóstrofo y guion)', () {
      expect(NameValidator.validar('Juan Pérez'), isNull);
      expect(NameValidator.validar('María José'), isNull);
      expect(NameValidator.validar("O'Connor"), isNull);
      expect(NameValidator.validar('Ana-Lucía'), isNull);
    });

    test('rechaza vacío o muy corto', () {
      expect(NameValidator.validar(''), isNotNull);
      expect(NameValidator.validar(null), isNotNull);
      expect(NameValidator.validar('J'), isNotNull);
    });

    test('rechaza números y símbolos', () {
      expect(NameValidator.validar('Juan123'), isNotNull);
      expect(NameValidator.validar('Juan@'), isNotNull);
    });

    test('rechaza letras repetidas (nombre no serio)', () {
      expect(NameValidator.validar('aaaa'), isNotNull);
      expect(NameValidator.validar('Luuuis'), isNotNull);
    });

    test('rechaza palabras de la lista negra', () {
      expect(NameValidator.validar('test'), isNotNull);
      expect(NameValidator.validar('prueba'), isNotNull);
    });

    test('normalizar capitaliza y colapsa espacios', () {
      expect(NameValidator.normalizar('juan  pérez '), 'Juan Pérez');
    });
  });

  group('PasswordValidator.validar', () {
    test('acepta 8+ caracteres con letra y número', () {
      expect(PasswordValidator.validar('abcd1234'), isNull);
      expect(PasswordValidator.validar('sire2026x'), isNull);
    });

    test('rechaza menos de 8 caracteres', () {
      expect(PasswordValidator.validar('ab12'), isNotNull);
    });

    test('rechaza sin número', () {
      expect(PasswordValidator.validar('abcdefgh'), isNotNull);
    });

    test('rechaza sin letra', () {
      expect(PasswordValidator.validar('12345678'), isNotNull);
    });

    test('rechaza null o vacío', () {
      expect(PasswordValidator.validar(null), isNotNull);
      expect(PasswordValidator.validar(''), isNotNull);
    });
  });
}
