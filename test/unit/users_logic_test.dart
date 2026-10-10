import 'package:flutter_test/flutter_test.dart';
import 'package:sire/features/users/domain/entities/account_status.dart';
import 'package:sire/features/users/domain/entities/app_user.dart';
import 'package:sire/features/users/domain/entities/user_role.dart';
import 'package:sire/features/users/presentation/providers/approvals_providers.dart';
import 'package:sire/features/users/presentation/providers/users_providers.dart';

AppUser _u({
  required String id,
  UserRole rol = UserRole.ciudadano,
  String aldea = '',
  String aldeaSolicitada = '',
  AccountStatus estado = AccountStatus.aprobado,
  bool esResponsable = false,
}) =>
    AppUser(
      id: id,
      nombre: id,
      telefono: '55550000',
      rol: rol,
      aldea: aldea,
      aldeaSolicitada: aldeaSolicitada,
      estadoCuenta: estado,
      esResponsable: esResponsable,
    );

/// Pruebas de la lógica de ruteo por rol/aldea (mínimo privilegio), compartida
/// por la app móvil y el panel web. Funciones puras.
void main() {
  final muni = _u(id: 'muni', rol: UserRole.municipalidad);
  final cocodeA = _u(id: 'cocodeA', rol: UserRole.cocode, aldea: 'A');
  final auxB = _u(id: 'auxB', rol: UserRole.auxiliatura, aldea: 'B');
  final pendA =
      _u(id: 'pendA', estado: AccountStatus.pendienteRevision, aldeaSolicitada: 'A');
  final pendB =
      _u(id: 'pendB', estado: AccountStatus.pendienteRevision, aldeaSolicitada: 'B');
  final aprobadoA = _u(id: 'aprA', aldea: 'A');
  final todos = [muni, cocodeA, pendA, pendB, aprobadoA];

  group('pendientesPara', () {
    test('Municipalidad ve todos los pendientes del municipio', () {
      final r = pendientesPara(todos, muni);
      expect(r.length, 2);
      expect(r.map((u) => u.id), containsAll(['pendA', 'pendB']));
    });

    test('COCODE ve solo los pendientes que declararon su aldea', () {
      final r = pendientesPara(todos, cocodeA);
      expect(r.map((u) => u.id).toList(), ['pendA']);
    });

    test('Alcaldía Auxiliar ve solo los pendientes de su aldea', () {
      final r = pendientesPara(todos, auxB);
      expect(r.map((u) => u.id).toList(), ['pendB']);
    });

    test('un ciudadano no ve solicitudes pendientes', () {
      expect(pendientesPara(todos, aprobadoA), isEmpty);
    });
  });

  group('usuariosVisiblesPara', () {
    test('Municipalidad ve a todos', () {
      expect(usuariosVisiblesPara(todos, muni).length, todos.length);
    });

    test('COCODE ve los de su aldea (aldea o aldeaSolicitada)', () {
      final ids = usuariosVisiblesPara(todos, cocodeA).map((u) => u.id).toSet();
      expect(ids, containsAll(['pendA', 'aprA']));
      expect(ids.contains('pendB'), isFalse);
    });

    test('Alcaldía Auxiliar ve solo los de su aldea', () {
      final ids = usuariosVisiblesPara(todos, auxB).map((u) => u.id).toSet();
      expect(ids, contains('pendB'));
      expect(ids.contains('pendA'), isFalse);
      expect(ids.contains('aprA'), isFalse);
    });

    test('sin actor => lista vacía', () {
      expect(usuariosVisiblesPara(todos, null), isEmpty);
    });
  });

  group('rolesAsignablesPor', () {
    test('Municipalidad asigna cualquier rol', () {
      expect(rolesAsignablesPor(muni), UserRole.values);
    });

    test('responsable de la Alcaldía Auxiliar: integrante (por defecto) o ciudadano',
        () {
      final resp = _u(
          id: 'resp', rol: UserRole.auxiliatura, aldea: 'B', esResponsable: true);
      expect(rolesAsignablesPor(resp),
          [UserRole.auxiliatura, UserRole.ciudadano]);
    });

    test('integrante común de la Alcaldía Auxiliar y COCODE: solo ciudadano', () {
      expect(rolesAsignablesPor(auxB), [UserRole.ciudadano]);
      expect(rolesAsignablesPor(cocodeA), [UserRole.ciudadano]);
    });
  });
}
