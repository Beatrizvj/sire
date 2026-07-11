import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../users/domain/entities/app_user.dart';
import '../../../users/presentation/providers/users_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authControllerProvider).user;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('No hay sesión activa.')));
    }

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
          Text(
            user.displayName ?? user.email ?? 'Usuario',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          FutureBuilder<AppUser?>(
            future: ref.read(userRepositoryProvider).getUser(user.uid),
            builder: (context, snapshot) {
              final profile = snapshot.data;
              return Column(
                children: [
                  _InfoTile(
                    icon: Icons.badge_outlined,
                    title: 'Rol',
                    subtitle: profile?.rol.label ?? '—',
                  ),
                  _InfoTile(
                    icon: Icons.phone_outlined,
                    title: 'Teléfono',
                    subtitle: (profile?.telefono.isNotEmpty ?? false)
                        ? profile!.telefono
                        : '—',
                  ),
                  _InfoTile(
                    icon: Icons.groups_outlined,
                    title: 'Aldea / Comunidad',
                    subtitle: (profile?.aldea.isNotEmpty ?? false)
                        ? profile!.aldea
                        : 'Sin asignar',
                  ),
                  _InfoTile(
                    icon: Icons.email_outlined,
                    title: 'Correo',
                    subtitle: user.email ?? '—',
                  ),
                ],
              );
            },
          ),
          const Divider(height: 32),
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '${AppConfig.appName} · v1'
              '${AppConfig.firebaseEnabled ? '' : ' (modo local)'}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
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
