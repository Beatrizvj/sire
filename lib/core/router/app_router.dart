import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/pages/admin_page.dart';
import '../../features/alerts/presentation/pages/home_sos_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/maps/presentation/pages/map_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import 'app_routes.dart';
import 'app_shell.dart';

/// Configuración de navegación de SIRE.
///
/// La app abre directamente en la pantalla SOS (`/home`) para facilitar las
/// pruebas. El login es un placeholder alcanzable desde Perfil; se conectará a
/// Firebase Auth en el Hito 3.
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.admin,
                builder: (context, state) => const AdminPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
