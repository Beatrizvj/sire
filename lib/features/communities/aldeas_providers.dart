import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/config/firestore_collections.dart';

/// Aldeas base del municipio de San Miguel Sigüilá (Cabecera + 3 aldeas). Son el
/// alcance documentado en la tesis y SIEMPRE están presentes; la Municipalidad
/// puede AGREGAR nuevas comunidades desde el panel (escalabilidad, Cap. III).
const aldeasBase = <String>['Cabecera', 'La Ciénaga', 'La Emboscada', 'El Llano'];

/// Repositorio de la colección `aldeas`. Solo guarda las comunidades AGREGADAS;
/// las base se combinan en [aldeasProvider].
class AldeasRepository {
  AldeasRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(FirestoreCollections.aldeas);

  Stream<List<String>> watchAgregadas() => _col.snapshots().map((snap) => snap
      .docs
      .map((d) => (d.data()['nombre'] as String?)?.trim() ?? '')
      .where((n) => n.isNotEmpty)
      .toList());

  /// Agrega una comunidad. El id del documento es el propio nombre para evitar
  /// duplicados.
  Future<void> agregar(String nombre) {
    final limpio = nombre.trim();
    return _col.doc(limpio).set({
      'nombre': limpio,
      'creadoEn': FieldValue.serverTimestamp(),
    });
  }

  /// Elimina una comunidad AGREGADA. Las base ([aldeasBase]) no viven en esta
  /// colección, así que nunca se borran: siempre reaparecen en [aldeasProvider].
  Future<void> eliminar(String nombre) => _col.doc(nombre.trim()).delete();
}

final aldeasRepositoryProvider = Provider<AldeasRepository>(
  (ref) => AldeasRepository(FirebaseFirestore.instance),
);

/// Lista de aldeas del municipio: las 4 base más las que la Municipalidad haya
/// agregado, con la Cabecera primero y las nuevas ordenadas al final. La usan el
/// registro, las aprobaciones, la gestión de usuarios y el panel, de modo que
/// agregar una comunidad se refleja en todo el sistema sin tocar código.
final aldeasProvider = StreamProvider.autoDispose<List<String>>((ref) {
  if (!AppConfig.firebaseEnabled) {
    return Stream<List<String>>.value(List.of(aldeasBase));
  }
  return ref.watch(aldeasRepositoryProvider).watchAgregadas().map((agregadas) {
    final extras = agregadas.where((a) => !aldeasBase.contains(a)).toList()
      ..sort();
    return [...aldeasBase, ...extras];
  });
});
