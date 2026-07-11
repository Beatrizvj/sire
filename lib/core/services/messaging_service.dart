import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../config/app_config.dart';
import 'logger_service.dart';

final messagingServiceProvider = Provider<MessagingService>(
  (ref) => MessagingService(ref.watch(loggerProvider)),
);

/// Scaffold de Firebase Cloud Messaging (Hito 4).
///
/// Queda inactivo hasta que [AppConfig.firebaseEnabled] sea true y Firebase
/// esté inicializado. Aquí se solicitarán permisos, se obtendrá el token FCM y
/// se escucharán los mensajes entrantes.
class MessagingService {
  MessagingService(this._logger);

  final Logger _logger;

  Future<void> init() async {
    if (!AppConfig.firebaseEnabled) return;

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    final token = await messaging.getToken();
    _logger.i('FCM token: $token');

    FirebaseMessaging.onMessage.listen((message) {
      _logger.i('Push recibido: ${message.notification?.title}');
    });
  }
}
