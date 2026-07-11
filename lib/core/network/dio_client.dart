import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/logger_service.dart';

/// Cliente HTTP compartido. Aún no se usa en v1; queda listo para consumir
/// REST/Cloud Functions (WhatsApp, etc.) en hitos posteriores.
final dioProvider = Provider<Dio>((ref) {
  final logger = ref.watch(loggerProvider);

  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        logger.d('➡️  ${options.method} ${options.uri}');
        handler.next(options);
      },
      onError: (error, handler) {
        logger.e('❌  ${error.requestOptions.uri}', error: error);
        handler.next(error);
      },
    ),
  );

  return dio;
});
