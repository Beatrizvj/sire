import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/firestore_collections.dart';
import '../domain/incident_category.dart';

/// CRUD del catálogo de categorías de incidente (R3).
abstract interface class IncidentCategoryRepository {
  Stream<List<IncidentCategory>> watchAll();
  Future<void> add(String nombre);
  Future<void> setActivo(String id, bool activo);
  Future<void> remove(String id);

  /// Crea las categorías por defecto si la colección está vacía (idempotente).
  Future<void> seedDefaultsIfEmpty();
}

class IncidentCategoryRepositoryFirestore
    implements IncidentCategoryRepository {
  IncidentCategoryRepositoryFirestore(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirestoreCollections.categoriasIncidente);

  @override
  Stream<List<IncidentCategory>> watchAll() =>
      _col.orderBy('orden').snapshots().map((snap) => snap.docs
          .map((d) => IncidentCategory(
                id: d.id,
                nombre: d.data()['nombre'] as String? ?? '',
                orden: (d.data()['orden'] as num?)?.toInt() ?? 0,
                activo: d.data()['activo'] as bool? ?? true,
              ))
          .toList(growable: false));

  @override
  Future<void> add(String nombre) => _col.add({
        'nombre': nombre.trim(),
        'orden': DateTime.now().millisecondsSinceEpoch,
        'activo': true,
      });

  @override
  Future<void> setActivo(String id, bool activo) =>
      _col.doc(id).update({'activo': activo});

  @override
  Future<void> remove(String id) => _col.doc(id).delete();

  @override
  Future<void> seedDefaultsIfEmpty() async {
    final snap = await _col.limit(1).get();
    if (snap.docs.isNotEmpty) return;
    final batch = _firestore.batch();
    for (var i = 0; i < categoriasPorDefecto.length; i++) {
      batch.set(_col.doc(), {
        'nombre': categoriasPorDefecto[i],
        'orden': i,
        'activo': true,
      });
    }
    await batch.commit();
  }
}

/// Modo demo local: catálogo fijo con las 3 por defecto (sin edición).
class IncidentCategoryRepositoryLocal implements IncidentCategoryRepository {
  const IncidentCategoryRepositoryLocal();

  @override
  Stream<List<IncidentCategory>> watchAll() => Stream.value([
        for (var i = 0; i < categoriasPorDefecto.length; i++)
          IncidentCategory(id: '$i', nombre: categoriasPorDefecto[i], orden: i),
      ]);

  @override
  Future<void> add(String nombre) async {}
  @override
  Future<void> setActivo(String id, bool activo) async {}
  @override
  Future<void> remove(String id) async {}
  @override
  Future<void> seedDefaultsIfEmpty() async {}
}

final incidentCategoryRepositoryProvider =
    Provider<IncidentCategoryRepository>((ref) {
  if (AppConfig.firebaseEnabled) {
    return IncidentCategoryRepositoryFirestore(FirebaseFirestore.instance);
  }
  return const IncidentCategoryRepositoryLocal();
});

/// Todas las categorías (para el panel de administración).
final categoriasProvider = StreamProvider.autoDispose<List<IncidentCategory>>(
  (ref) => ref.watch(incidentCategoryRepositoryProvider).watchAll(),
);

/// Nombres de las categorías ACTIVAS, para los selectores del ciudadano/autoridad.
/// Si aún no hay datos (sin sembrar u offline), usa las 3 por defecto.
final categoriasActivasProvider = Provider.autoDispose<List<String>>((ref) {
  final cats = ref.watch(categoriasProvider).asData?.value;
  if (cats == null || cats.isEmpty) return categoriasPorDefecto;
  final activas = cats.where((c) => c.activo).map((c) => c.nombre).toList();
  return activas.isEmpty ? categoriasPorDefecto : activas;
});
