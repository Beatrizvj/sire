import 'package:flutter/material.dart';

/// Pantalla reutilizable para secciones que se implementarán en hitos
/// posteriores. Muestra el título, un ícono y a qué hito pertenece.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.icon,
    required this.description,
    this.milestone,
  });

  final String title;
  final IconData icon;
  final String description;
  final String? milestone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              if (milestone != null) ...[
                const SizedBox(height: 24),
                Chip(
                  avatar: const Icon(Icons.flag_outlined, size: 18),
                  label: Text('Próximamente · $milestone'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
