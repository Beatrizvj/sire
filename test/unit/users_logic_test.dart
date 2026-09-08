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
}) =>
    AppUser(
      id: id,
      nombre: id,
      telefono: '55550000',
      rol: rol,
      aldea: aldea,
      aldeaSolicitada: aldeaSolicitada,
      estadoCuenta: estado,
    );

/// Pruebas de la lógica de ruteo por rol/aldea (mínimo privilegio), compartida
/// por la app móvil y el panel web. Funciones puras.
void main() {
  final muni = _u(id: 'muni', rol: UserRole.municipalidad);
  final cocodeA = _u(id: 'cocodeA', rol: UserRole.cocode, aldea: 'A');
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

    test('sin actor => lista vacía', () {
      expect(usuariosVisiblesPara(todos, null), isEmpty);
    });
  });
}
