import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/app_providers.dart';
import '../../data/repositories/user_repository_firestore.dart';
import '../../data/repositories/user_repository_local.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/repositories/user_repository.dart';

/// Repositorio de usuarios. Cambia de local a Firestore según [AppConfig.firebaseEnabled].
final userRepositoryProvider = Provider<UserRepository>((ref) {
  if (AppConfig.firebaseEnabled) {
    return UserRepositoryFirestore(FirebaseFirestore.instance);
  }
  return UserRepositoryLocal(ref.watch(sharedPreferencesProvider));
});

/// Todos los usuarios en tiempo real, para la pantalla de Gestión (Municipalidad).
final allUsersProvider = StreamProvider.autoDispose<List<AppUser>>(
  (ref) => ref.watch(userRepositoryProvider).watchAllUsers(),
);

/// Usuarios que una autoridad puede ver/gestionar (mínimo privilegio):
/// - Municipalidad: TODOS los del municipio.
/// - COCODE: solo los de SU aldea (aprobados con esa aldea, o pendientes que la
///   declararon como aldeaSolicitada), para que gestione únicamente su comunidad.
List<AppUser> usuariosVisiblesPara(List<AppUser> todos, AppUser? actor) {
  if (actor == null) return const [];
  if (actor.rol == UserRole.municipalidad) return todos;
  if (actor.rol == UserRole.cocode) {
    final mi = actor.aldea;
    return todos
        .where((u) => u.aldea == mi || u.aldeaSolicitada == mi)
        .toList(growable: false);
  }
  return const [];
}
