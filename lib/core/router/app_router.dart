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
import '../../features/users/domain/entities/user_role.dart';
import 'app_routes.dart';
import 'app_shell.dart';

/// Notifica al router cuando cambia la sesión o el perfil (rol) del usuario,
/// para que el `redirect` (incluido el guard por rol) se vuelva a evaluar.
class _RouterRefresh extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// Pantalla de inicio según el rol: el ciudadano arranca en el botón SOS;
/// las autoridades (COCODE/Municipalidad) en la bandeja de alertas.
String _inicioPorRol(UserRole rol) => switch (rol) {
      UserRole.ciudadano => AppRoutes.sos,
      UserRole.cocode || UserRole.municipalidad => AppRoutes.dashboard,
    };

/// ¿Puede este rol entrar a esta ruta? El Perfil es compartido. El SOS es solo
/// del ciudadano; la Bandeja (dashboard) y el Mapa de alertas activas son solo
/// de las autoridades (COCODE/Municipalidad), conforme a la Tabla 8 del PG2.
bool _rolPuedeAcceder(UserRole rol, String location) {
  if (location == AppRoutes.profile) return true;
  return switch (rol) {
    UserRole.ciudadano => location == AppRoutes.sos,
    UserRole.cocode ||
    UserRole.municipalidad =>
      location == AppRoutes.dashboard || location == AppRoutes.map,
  };
}

/// Configuración de navegación de SIRE, con guard de autenticación y de rol.
///
/// Sin sesión → `/login`. Con sesión → cada rol solo entra a sus pantallas;
/// si intenta otra, se le bloquea y regresa a su inicio (queda en el log).
/// El `refreshListenable` re-evalúa el `redirect` al cambiar sesión o perfil.
final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(authControllerProvider, (prev, next) => refresh.bump());
  ref.listen(currentUserProfileProvider, (prev, next) => refresh.bump());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authControllerProvider).isLoggedIn;
      final location = state.matchedLocation;
      final onAuthPage =
          location == AppRoutes.login || location == AppRoutes.register;

      if (!loggedIn) return onAuthPage ? null : AppRoutes.login;

      // Perfil (con rol) del usuario. Puede estar aún cargando tras el login.
      final perfil = ref.read(currentUserProfileProvider).asData?.value;

      if (onAuthPage) {
        // Ya con sesión: mándalo a su inicio según el rol (o al dashboard
        // mientras el rol termina de cargar).
        return perfil == null ? AppRoutes.dashboard : _inicioPorRol(perfil.rol);
      }

      // Rol todavía no disponible: no bloqueamos aún; el refresh reevaluará.
      if (perfil == null) return null;

      // Guard por rol: si la ruta no le corresponde, se bloquea y se registra.
      if (!_rolPuedeAcceder(perfil.rol, location)) {
        final inicio = _inicioPorRol(perfil.rol);
        logAcceso(
          '🚫 BLOQUEADO · rol=${perfil.rol.label} intentó entrar a "$location" '
          '(no permitido) · redirigido a su inicio "$inicio".',
        );
        return inicio;
      }
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
