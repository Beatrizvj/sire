import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/app_providers.dart';
import '../../data/repositories/user_repository_firestore.dart';
import '../../data/repositories/user_repository_local.dart';
import '../../domain/repositories/user_repository.dart';

/// Repositorio de usuarios. Cambia de local a Firestore según [AppConfig.firebaseEnabled].
final userRepositoryProvider = Provider<UserRepository>((ref) {
  if (AppConfig.firebaseEnabled) {
    return UserRepositoryFirestore(FirebaseFirestore.instance);
  }
  return UserRepositoryLocal(ref.watch(sharedPreferencesProvider));
});
