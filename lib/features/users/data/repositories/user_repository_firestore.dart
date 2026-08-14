import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/config/firestore_collections.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/user_repository.dart';
import '../models/app_user_model.dart';

/// Implementación de [UserRepository] con Cloud Firestore (colección `usuarios`).
class UserRepositoryFirestore implements UserRepository {
  UserRepositoryFirestore(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestoreCollections.usuarios);

  @override
  Future<AppUser?> getUser(String id) async {
    final doc = await _users.doc(id).get();
    final data = doc.data();
    if (data == null) return null;
    return AppUserModel.fromMap(data, id: doc.id);
  }

  @override
  Stream<AppUser?> watchUser(String id) => _users.doc(id).snapshots().map((doc) {
        final data = doc.data();
        return data == null ? null : AppUserModel.fromMap(data, id: doc.id);
      });

  @override
  Future<void> saveUser(AppUser user) =>
      _users.doc(user.id).set(AppUserModel.toMap(user), SetOptions(merge: true));

  @override
  Future<void> deleteUser(String id) => _users.doc(id).delete();

  @override
  Stream<List<AppUser>> watchAllUsers() =>
      _users.orderBy('nombre').snapshots().map(
            (snap) => snap.docs
                .map((doc) => AppUserModel.fromMap(doc.data(), id: doc.id))
                .toList(growable: false),
          );
}
