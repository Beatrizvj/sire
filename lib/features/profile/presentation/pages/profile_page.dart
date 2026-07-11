import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/router/app_routes.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          CircleAvatar(
            radius: 44,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(Icons.person,
                size: 48, color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text('Usuario de prueba',
              textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          Text('Rol: ciudadano',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          const SizedBox(height: 24),
          const _InfoTile(
            icon: Icons.badge_outlined,
            title: 'Perfil y roles',
            subtitle: 'Ciudadano, COCODE, Monitor, Administrador · Hito 2/3',
          ),
          const _InfoTile(
            icon: Icons.groups_outlined,
            title: 'Comunidad / aldea',
            subtitle: 'Se asignará al conectar Firestore · Hito 3',
          ),
          const Divider(height: 32),
          OutlinedButton.icon(
            onPressed: () => context.go(AppRoutes.login),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión (demo)'),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('${AppConfig.appName} · v1 (pruebas locales)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
