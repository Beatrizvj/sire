import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/services/messaging_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'features/auth/presentation/providers/auth_providers.dart';

/// Widget raíz de SIRE.
class SireApp extends ConsumerWidget {
  const SireApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    // Notificaciones push: registra el token FCM del dispositivo cuando hay
    // sesión y lo olvida al cerrarla. Es no-op salvo que AppConfig.pushEnabled
    // esté activo (ver docs/PUSH_SETUP.md).
    ref.listen(authControllerProvider.select((s) => s.user?.uid), (_, uid) {
      final svc = ref.read(messagingServiceProvider);
      if (uid != null) {
        svc.registrarTokenPara(uid);
      } else {
        svc.olvidarSesion();
      }
    });
    final uidActual = ref.read(authControllerProvider).user?.uid;
    if (uidActual != null) {
      ref.read(messagingServiceProvider).registrarTokenPara(uidActual);
    }

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
    );
  }
}
