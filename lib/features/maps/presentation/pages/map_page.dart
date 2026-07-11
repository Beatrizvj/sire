import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_page.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Mapa en tiempo real',
      icon: Icons.map_outlined,
      description:
          'Aquí se mostrarán las alertas activas sobre Google Maps: '
          'marcadores, rutas, distancias y ubicación actual.',
      milestone: 'Hito 5 · Google Maps',
    );
  }
}
