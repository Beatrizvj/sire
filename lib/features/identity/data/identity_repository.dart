import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/firestore_collections.dart';

/// Verificación de identidad (R2): fotos del DPI (anverso/reverso).
///
/// Para evitar activar Firebase Storage (plan de pago), las imágenes —ya
/// comprimidas y livianas— se guardan como texto (base64) en Firestore. Cada
/// lado va en SU PROPIO documento, en la subcolección privada
/// `identidad/{uid}/fotos/{lado}`. Así ningún documento se acerca al límite de
/// 1 MB de Firestore. El acceso lo controlan las reglas: el dueño sube las
/// suyas y solo verificadores autorizados leen.
abstract interface class IdentityRepository {
  static const String anverso = 'anverso';
  static const String reverso = 'reverso';

  Future<void> subir({
    required String uid,
    required String lado, // 'anverso' | 'reverso'
    required Uint8List bytes,
  });

  /// Descarga los bytes de una foto (para que la vea un verificador autorizado).
  Future<Uint8List?> descargar({required String uid, required String lado});

  /// Elimina las fotos de un usuario (retención / borrado por Municipalidad).
  Future<void> eliminar(String uid);
}

class IdentityRepositoryFirestore implements IdentityRepository {
  IdentityRepositoryFirestore(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String uid, String lado) =>
      _firestore
          .collection(FirestoreCollections.identidad)
          .doc(uid)
          .collection('fotos')
          .doc(lado);

  @override
  Future<void> subir({
    required String uid,
    required String lado,
    required Uint8List bytes,
  }) async {
    await _doc(uid, lado).set({
      'b64': base64Encode(bytes),
      'actualizadoEn': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<Uint8List?> descargar({
    required String uid,
    required String lado,
  }) async {
    try {
      final snap = await _doc(uid, lado).get();
      final b64 = snap.data()?['b64'] as String?;
      if (b64 == null || b64.isEmpty) return null;
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> eliminar(String uid) async {
    for (final lado in [IdentityRepository.anverso, IdentityRepository.reverso]) {
      try {
        await _doc(uid, lado).delete();
      } catch (_) {
        // Si no existe, se ignora.
      }
    }
  }
}

/// Modo demo local (sin Firebase): no-op.
class IdentityRepositoryNoop implements IdentityRepository {
  const IdentityRepositoryNoop();

  @override
  Future<void> subir({
    required String uid,
    required String lado,
    required Uint8List bytes,
  }) async {}

  @override
  Future<Uint8List?> descargar({
    required String uid,
    required String lado,
  }) async =>
      null;

  @override
  Future<void> eliminar(String uid) async {}
}

final identityRepositoryProvider = Provider<IdentityRepository>((ref) {
  if (AppConfig.firebaseEnabled) {
    return IdentityRepositoryFirestore(FirebaseFirestore.instance);
  }
  return const IdentityRepositoryNoop();
});
