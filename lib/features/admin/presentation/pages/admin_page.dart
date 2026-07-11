import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_page.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Panel administrativo',
      icon: Icons.admin_panel_settings_outlined,
      description:
          'Dashboard, gestión de usuarios y comunidades, reportes y '
          'mapas de calor para la municipalidad y los COCODE.',
      milestone: 'Hito 7 · Panel Web',
    );
  }
}
