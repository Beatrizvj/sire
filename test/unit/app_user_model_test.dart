import 'package:flutter_test/flutter_test.dart';
import 'package:sire/features/users/data/models/app_user_model.dart';
import 'package:sire/features/users/domain/entities/account_status.dart';
import 'package:sire/features/users/domain/entities/app_user.dart';
import 'package:sire/features/users/domain/entities/user_role.dart';

/// Pruebas de serialización del perfil de usuario (JSON local ⇄ objeto de
/// dominio). Verifica que ningún campo se pierda y que los documentos antiguos
/// sin ciertos campos se interpreten de forma segura.
void main() {
  group('AppUserModel round-trip (encode/decode)', () {
    test('conserva todos los campos', () {
      final u = AppUser(
        id: 'uid-1',
        nombre: 'Juan Pérez',
        telefono: '55551234',
        email: 'juan@example.com',
        rol: UserRole.cocode,
        aldea: 'Centro',
        estadoCuenta: AccountStatus.aprobado,
        aldeaSolicitada: 'Centro',
        aprobadoPor: 'muni-1',
        aprobadoEn: DateTime(2026, 3, 15, 10, 30),
        puedeVerIdentidad: true,
        contactosConfianza: const ['c1', 'c2'],
      );
      final back = AppUserModel.decode(AppUserModel.encode(u));
      expect(back, u);
    });
  });

  group('AppUserModel.fromMap valores por defecto', () {
    test('documento vacío => ciudadano aprobado, sin permisos', () {
      final u = AppUserModel.fromMap(const {}, id: 'x');
      expect(u.id, 'x');
      expect(u.nombre, '');
      expect(u.rol, UserRole.ciudadano);
      expect(u.estadoCuenta, AccountStatus.aprobado);
      expect(u.puedeVerIdentidad, isFalse);
      expect(u.contactosConfianza, isEmpty);
    });
  });
}
