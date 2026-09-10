import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../config/app_config.dart';
import '../config/firestore_collections.dart';
import 'logger_service.dart';

final messagingServiceProvider = Provider<MessagingService>(
  (ref) => MessagingService(ref.watch(loggerProvider)),
);

/// Notificaciones push con Firebase Cloud Messaging (FCM).
///
/// Registra el token FCM del dispositivo bajo `usuarios/{uid}.fcmTokens` para
/// que la Cloud Function `notificarNuevaAlerta` avise a las autoridades cuando
/// entra una alerta. Todo queda INACTIVO salvo que [AppConfig.firebaseEnabled]
/// y [AppConfig.pushEnabled] sean true — este último se activa al desplegar la
/// función en un proyecto con plan Blaze (ver docs/PUSH_SETUP.md).
class MessagingService {
  MessagingService(this._logger);

  final Logger _logger;
  String? _uidRegistrado;

  bool get _activo => AppConfig.firebaseEnabled && AppConfig.pushEnabled;

  /// Pide permiso de notificaciones, obtiene el token FCM y lo guarda en el
  /// perfil del usuario. Idempotente por sesión (no repite para el mismo uid).
  Future<void> registrarTokenPara(String uid) async {
    if (!_activo || uid.isEmpty || _uidRegistrado == uid) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _guardarToken(uid, token);
      _uidRegistrado = uid;
      _logger.i('FCM: token registrado para $uid');

      // Si el token rota, se vuelve a guardar bajo el mismo perfil.
      messaging.onTokenRefresh.listen((t) => _guardarToken(uid, t));
      // Mensajes con la app en primer plano (el aviso visual ya lo da la alarma).
      FirebaseMessaging.onMessage.listen(
        (m) => _logger.i('FCM push recibido: ${m.notification?.title}'),
      );
    } catch (e) {
      _logger.w('FCM: no se pudo registrar el token: $e');
    }
  }

  Future<void> _guardarToken(String uid, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreCollections.usuarios)
          .doc(uid)
          .update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (e) {
      _logger.w('FCM: no se pudo guardar el token: $e');
    }
  }

  /// Olvida el registro de la sesión actual (para re-registrar en el próximo
  /// inicio de sesión, posiblemente con otro usuario en el mismo dispositivo).
  void olvidarSesion() => _uidRegistrado = null;
}
