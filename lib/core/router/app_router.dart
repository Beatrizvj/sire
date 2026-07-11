import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/alerts/presentation/pages/home_sos_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/maps/presentation/pages/map_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import 'app_routes.dart';
import 'app_shell.dart';

/// Configuración de navegación de SIRE, con guard de autenticación.
///
/// Sin sesión → `/login`. Con sesión → app (dashboard/SOS/mapa/perfil).
/// El `refreshListenable` re-evalúa el `redirect` en cada cambio de sesión.
final goRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier =
      ValueNotifier<bool>(ref.read(authControllerProvider).isLoggedIn);
  ref.listen(authControllerProvider, (previous, next) {
    authNotifier.value = next.isLoggedIn;
  });
  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final loggedIn = ref.read(authControllerProvider).isLoggedIn;
      final location = state.matchedLocation;
      final onAuthPage =
          location == AppRoutes.login || location == AppRoutes.register;

      if (!loggedIn) return onAuthPage ? null : AppRoutes.login;
      if (onAuthPage) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.sos,
                builder: (context, state) => const HomeSosPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.map,
                builder: (context, state) => const MapPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
