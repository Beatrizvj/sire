import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/dashboard/presentation/pages/web_panel.dart';
import '../../features/users/domain/entities/account_status.dart';
import '../../features/users/domain/entities/app_user.dart';
import '../../features/users/domain/entities/user_role.dart';
import '../services/alert_monitor_bridge.dart';

/// Contenedor de navegación:
/// - **Web**: consola [WebPanel] solo para COCODE/Municipalidad; el ciudadano
///   ve un aviso ([_AccesoSoloAutoridad]) — no tiene acceso al panel.
/// - **App móvil**: barra inferior de navegación.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // R1: primero el guard de aprobación. Una cuenta que no está aprobada NO
    // accede a ninguna función (ni panel web ni app móvil), vea el rol que vea.
    final perfilAsync = ref.watch(currentUserProfileProvider);
    if (perfilAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final perfil = perfilAsync.asData?.value;
    if (perfil != null && !perfil.puedeAcceder) {
      return _CuentaEnRevision(estado: perfil.estadoCuenta);
    }

    // En web: el acceso al panel depende del rol.
    if (kIsWeb) {
      final esAutoridad = perfil?.rol == UserRole.cocode ||
          perfil?.rol == UserRole.municipalidad;
      return esAutoridad ? const WebPanel() : const _AccesoSoloAutoridad();
    }

    // App móvil: barra inferior según el rol. Cada rol ve solo sus pestañas
    // (Tabla 8 del PG2, principio de mínimo privilegio): el Ciudadano usa SOS y
    // Perfil; las autoridades (COCODE/Municipalidad) usan Inicio —la Bandeja—,
    // Mapa y Perfil. Envuelto en _AlertMonitorGate: si el usuario es autoridad,
    // arranca el servicio nativo que hace sonar la alarma aunque la app esté en
    // segundo plano.
    final items = _navItemsPorRol(perfil?.rol ?? UserRole.ciudadano);
    // El branch actual del router, traducido a la posición visible del rol.
    var seleccion =
        items.indexWhere((it) => it.branch == navigationShell.currentIndex);
    if (seleccion < 0) seleccion = 0;

    return _AlertMonitorGate(
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: seleccion,
          onDestinationSelected: (i) {
            final branch = items[i].branch;
            navigationShell.goBranch(
              branch,
              initialLocation: branch == navigationShell.currentIndex,
            );
          },
          destinations: [
            for (final it in items)
              NavigationDestination(
                icon: Icon(it.icon),
                selectedIcon: Icon(it.selectedIcon),
                label: it.label,
              ),
          ],
        ),
      ),
    );
  }
}

/// Un destino de la barra inferior asociado a su rama (branch) del router.
/// Orden de las ramas en el router: 0=Inicio (Bandeja) · 1=SOS · 2=Mapa · 3=Perfil.
class _NavItem {
  const _NavItem(this.branch, this.icon, this.selectedIcon, this.label);
  final int branch;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Pestañas visibles según el rol (Tabla 8 del PG2):
/// - Ciudadano: SOS y Perfil (registrarse, emitir SOS, compartir ubicación y
///   consultar su perfil; la ubicación se adjunta sola al SOS, RF-03).
/// - COCODE / Municipalidad: Inicio (Bandeja), Mapa de alertas activas y Perfil.
List<_NavItem> _navItemsPorRol(UserRole rol) {
  const inicio = _NavItem(0, Icons.home_outlined, Icons.home, 'Inicio');
  const sos = _NavItem(1, Icons.sos_outlined, Icons.sos, 'SOS');
  const mapa = _NavItem(2, Icons.map_outlined, Icons.map, 'Mapa');
  const perfil = _NavItem(3, Icons.person_outline, Icons.person, 'Perfil');
  return switch (rol) {
    UserRole.ciudadano => [sos, perfil],
    UserRole.cocode || UserRole.municipalidad => [inicio, mapa, perfil],
  };
}

/// R1: pantalla para una cuenta que aún no ha sido aprobada por una autoridad.
/// Aplica igual en web y en móvil: sin acceso a funciones hasta la aprobación.
class _CuentaEnRevision extends ConsumerWidget {
  const _CuentaEnRevision({required this.estado});

  final AccountStatus estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (icono, color, titulo, detalle) = switch (estado) {
      AccountStatus.rechazado => (
          Icons.cancel_outlined,
          theme.colorScheme.error,
          'Cuenta no aprobada',
          'Tu solicitud fue rechazada. Comunícate con el COCODE de tu aldea o '
              'con la Municipalidad para más información.',
        ),
      AccountStatus.suspendido => (
          Icons.pause_circle_outline,
          theme.colorScheme.error,
          'Cuenta suspendida',
          'Tu cuenta fue suspendida temporalmente. Comunícate con la '
              'Municipalidad para regularizar tu acceso.',
        ),
      _ => (
          Icons.hourglass_top_outlined,
          theme.colorScheme.primary,
          'Cuenta en revisión',
          'Tu cuenta fue creada y está pendiente de aprobación. Una autoridad '
              '(COCODE de tu aldea o la Municipalidad) validará tu identidad y '
              'te asignará un rol. Podrás usar SIRE cuando sea aprobada.',
        ),
    };
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icono, size: 64, color: color),
                const SizedBox(height: 20),
                Text(titulo,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(
                  detalle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso para quien entra al panel web sin ser autoridad (ciudadano).
class _AccesoSoloAutoridad extends ConsumerWidget {
  const _AccesoSoloAutoridad();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline,
                    size: 64, color: theme.colorScheme.error),
                const SizedBox(height: 20),
                Text('Panel exclusivo',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(
                  'Este panel web es solo para COCODE y la Municipalidad. '
                  'Como ciudadano, usa la aplicación móvil SIRE para enviar '
                  'y seguir tus alertas.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Arranca/detiene el servicio nativo de monitoreo de alertas según la sesión:
/// activo solo para autoridades (COCODE/Municipalidad) aprobadas. Así el teléfono
/// de la autoridad suena al entrar una alerta aunque la app esté en segundo plano.
class _AlertMonitorGate extends ConsumerStatefulWidget {
  const _AlertMonitorGate({required this.child});

  final Widget child;

  @override
  ConsumerState<_AlertMonitorGate> createState() => _AlertMonitorGateState();
}

class _AlertMonitorGateState extends ConsumerState<_AlertMonitorGate> {
  // Firma de la última configuración aplicada, para no reiniciar el servicio en
  // cada frame. Incluye el uid + el filtro ('uid|off', 'uid|todos',
  // 'uid|c:uid1,uid2'), para que un cambio de cuenta SIEMPRE reinicie el
  // monitoreo (listener re-autenticado y base de "conocidas" limpia), aunque el
  // rol sea el mismo.
  String? _ultimaFirma;

  void _sync(AppUser? perfil) {
    var todos = false;
    var contactos = const <String>[];
    final String config;
    if (perfil == null || !perfil.puedeAcceder) {
      config = 'off';
    } else if (perfil.rol == UserRole.cocode ||
        perfil.rol == UserRole.municipalidad) {
      todos = true;
      config = 'todos';
    } else if (perfil.rol == UserRole.ciudadano &&
        perfil.contactosConfianza.isNotEmpty) {
      // RF-11: el ciudadano es contacto de confianza de alguien → oye las
      // alertas de los vecinos que la autoridad le asignó.
      contactos = perfil.contactosConfianza;
      config = 'c:${(contactos.toList()..sort()).join(',')}';
    } else {
      config = 'off';
    }
    final firma = '${perfil?.id ?? '-'}|$config';
    if (firma == _ultimaFirma) return;
    _ultimaFirma = firma;
    final bridge = ref.read(alertMonitorBridgeProvider);
    if (config == 'off') {
      bridge.stop();
    } else {
      bridge.start(todos: todos, contactos: contactos);
    }
  }

  @override
  void dispose() {
    if (_ultimaFirma != null && !_ultimaFirma!.endsWith('|off')) {
      ref.read(alertMonitorBridgeProvider).stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(currentUserProfileProvider).asData?.value;
    // Efecto idempotente tras el frame (evita tocar el servicio durante el build):
    // arranca o detiene el monitoreo según el rol de la sesión.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(perfil);
    });
    return widget.child;
  }
}
