import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/user_repository.dart';
import '../models/app_user_model.dart';

/// Implementación local de [UserRepository] (demo sin Firebase).
class UserRepositoryLocal implements UserRepository {
  const UserRepositoryLocal(this._prefs);

  final SharedPreferences _prefs;

  String _key(String id) => 'sire_user_$id';

  @override
  Future<AppUser?> getUser(String id) async {
    final raw = _prefs.getString(_key(id));
    if (raw == null) return null;
    try {
      return AppUserModel.decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<AppUser?> watchUser(String id) async* {
    yield await getUser(id);
  }

  @override
  Future<void> saveUser(AppUser user) =>
      _prefs.setString(_key(user.id), AppUserModel.encode(user));

  @override
  Future<void> deleteUser(String id) => _prefs.remove(_key(id));

  @override
  Stream<List<AppUser>> watchAllUsers() async* {
    yield const [];
  }
}
