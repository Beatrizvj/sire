import 'package:flutter_test/flutter_test.dart';
import 'package:sire/features/users/domain/entities/account_status.dart';
import 'package:sire/features/users/domain/entities/app_user.dart';
import 'package:sire/features/users/domain/entities/user_role.dart';
import 'package:sire/features/users/domain/permisos.dart';
import 'package:sire/features/users/presentation/providers/approvals_providers.dart';
import 'package:sire/features/users/presentation/providers/users_providers.dart';

AppUser _u({
  required String id,
  UserRole rol = UserRole.ciudadano,
  String aldea = '',
  String aldeaSolicitada = '',
  AccountStatus estado = AccountStatus.aprobado,
  bool esResponsable = false,
  bool puedeVerIdentidad = false,
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
      puedeVerIdentidad: puedeVerIdentidad,
    );

/// Pruebas de la lógica de ruteo por rol/aldea (mínimo privilegio), compartida
/// por la app móvil y el panel web. Funciones puras.
void main() {
  final muni = _u(id: 'muni', rol: UserRole.municipalidad);
  final cocodeA = _u(id: 'cocodeA', rol: UserRole.cocode, aldea: 'A');
  final auxB = _u(id: 'auxB', rol: UserRole.auxiliatura, aldea: 'B');
  final coordA = _u(
      id: 'coordA', rol: UserRole.cocode, aldea: 'A', esResponsable: true);
  final coordAuxB = _u(
      id: 'coordAuxB', rol: UserRole.auxiliatura, aldea: 'B', esResponsable: true);
  final delegadoA = _u(
      id: 'delA', rol: UserRole.cocode, aldea: 'A', puedeVerIdentidad: true);
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

    test('coordinador del COCODE ve solo los pendientes de su aldea', () {
      final r = pendientesPara(todos, coordA);
      expect(r.map((u) => u.id).toList(), ['pendA']);
    });

    test('coordinador de la Alcaldía Auxiliar ve solo los de su aldea', () {
      final r = pendientesPara(todos, coordAuxB);
      expect(r.map((u) => u.id).toList(), ['pendB']);
    });

    test('aprobador delegado ve los pendientes de su aldea', () {
      expect(pendientesPara(todos, delegadoA).map((u) => u.id).toList(),
          ['pendA']);
    });

    test('integrante sin coordinación ni delegación no ve solicitudes', () {
      expect(pendientesPara(todos, cocodeA), isEmpty);
      expect(pendientesPara(todos, auxB), isEmpty);
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

    test('coordinador: integrante de su cuerpo (por defecto) o ciudadano', () {
      expect(rolesAsignablesPor(coordAuxB),
          [UserRole.auxiliatura, UserRole.ciudadano]);
      expect(rolesAsignablesPor(coordA), [UserRole.cocode, UserRole.ciudadano]);
    });

    test('delegado e integrante común: solo ciudadano', () {
      expect(rolesAsignablesPor(delegadoA), [UserRole.ciudadano]);
      expect(rolesAsignablesPor(auxB), [UserRole.ciudadano]);
    });
  });

  group('permisos', () {
    test('solo Municipalidad, coordinador y delegado aprueban cuentas', () {
      expect(muni.puedeAprobarCuentas, isTrue);
      expect(coordA.puedeAprobarCuentas, isTrue);
      expect(delegadoA.puedeAprobarCuentas, isTrue);
      expect(cocodeA.puedeAprobarCuentas, isFalse);
      expect(aprobadoA.puedeAprobarCuentas, isFalse);
    });

    test('el coordinador edita integrantes y ciudadanos de su aldea', () {
      expect(coordA.puedeEditar(cocodeA), isTrue);
      expect(coordA.puedeEditar(aprobadoA), isTrue);
      expect(coordA.puedeEditar(auxB), isFalse); // otra aldea
    });

    test('nadie se edita a sí mismo ni el coordinador a otro coordinador', () {
      expect(coordA.puedeEditar(coordA), isFalse);
      expect(muni.puedeEditar(muni), isFalse);
      final otroCoord = _u(
          id: 'c2', rol: UserRole.cocode, aldea: 'A', esResponsable: true);
      expect(coordA.puedeEditar(otroCoord), isFalse);
    });

    test('un integrante común no edita a nadie', () {
      expect(cocodeA.puedeEditar(aprobadoA), isFalse);
      expect(delegadoA.puedeEditar(aprobadoA), isFalse);
    });

    test('cuenta los delegados de la aldea (sin el coordinador)', () {
      expect(delegadosEn([coordA, delegadoA, cocodeA], 'A', UserRole.cocode), 1);
    });

    test('a quién acude el ciudadano para corregir sus datos', () {
      expect(aprobadoA.autoridadParaCorrecciones([coordA]), 'el COCODE de A');
      final ciudB = _u(id: 'cB', aldea: 'B');
      expect(ciudB.autoridadParaCorrecciones([coordAuxB]),
          'la Alcaldía Auxiliar de B');
      expect(aprobadoA.autoridadParaCorrecciones(const []), 'la Municipalidad');
      expect(cocodeA.autoridadParaCorrecciones([coordA]), 'la Municipalidad');
    });
  });
}
