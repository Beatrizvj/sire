import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../alerts/domain/entities/alert_status.dart';
import '../../../alerts/domain/entities/sos_alert.dart';
import '../../../alerts/presentation/providers/alerts_providers.dart';

/// Centro aproximado del municipio de San Miguel Sigüilá (Quetzaltenango).
/// Encuadre inicial del mapa cuando aún no hay alertas activas con ubicación.
const LatLng _centroMunicipio = LatLng(14.8726, -91.6009);

/// Máximo de marcadores dibujados a la vez, para que el mapa no se sature cuando
/// hay muchas alertas activas (se muestran las más recientes).
const int _maxMarcadores = 80;

/// Mapa de alertas activas para las autoridades (COCODE / Municipalidad), sobre
/// OpenStreetMap. Coloca un marcador por cada alerta pendiente o en atención con
/// ubicación válida y se actualiza en vivo. Cumple la sección 3.4 del PG2: los
/// coordinadores visualizan la ubicación del incidente en tiempo real.
class MapPage extends ConsumerWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final alertsAsync = ref.watch(allAlertsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mapa de alertas activas')),
      body: alertsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudo cargar el mapa.\n$e',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        data: (alerts) {
          // Solo alertas activas (pendiente o en atención) con ubicación válida,
          // ordenadas de la más reciente a la más antigua.
          final activas = alerts
              .where((a) =>
                  (a.status == AlertStatus.pendiente ||
                      a.status == AlertStatus.atendida) &&
                  !(a.latitude == 0 && a.longitude == 0))
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          final centro = activas.isNotEmpty
              ? LatLng(activas.first.latitude, activas.first.longitude)
              : _centroMunicipio;

          // Se dibujan solo las más recientes para que el mapa no se sature.
          final marcadores = activas.take(_maxMarcadores).toList();

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: centro,
                  initialZoom: 14,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'gt.edu.miumg.sire',
                    errorTileCallback: (tile, error, stackTrace) =>
                        debugPrint('SIRE mapa · un tile no cargó: $error'),
                  ),
                  MarkerLayer(
                    markers: [
                      for (final a in marcadores)
                        Marker(
                          point: LatLng(a.latitude, a.longitude),
                          width: 44,
                          height: 44,
                          child: GestureDetector(
                            onTap: () => _mostrarDetalle(context, a),
                            child: Icon(
                              Icons.location_on,
                              size: 44,
                              color: a.status == AlertStatus.pendiente
                                  ? AppColors.statusPendiente
                                  : AppColors.statusAtendida,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (activas.isEmpty) const _SinAlertas(),
              const Positioned(left: 12, bottom: 12, child: _Leyenda()),
            ],
          );
        },
      ),
    );
  }

  void _mostrarDetalle(BuildContext context, SosAlert alert) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _DetalleAlerta(alert: alert),
    );
  }
}

/// Aviso central cuando no hay alertas activas que mostrar en el mapa.
class _SinAlertas extends StatelessWidget {
  const _SinAlertas();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline),
              SizedBox(width: 8),
              Text('No hay alertas activas en el mapa.'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Leyenda de colores de los marcadores.
class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LeyendaItem(color: AppColors.statusPendiente, texto: 'Pendiente'),
            const SizedBox(height: 4),
            _LeyendaItem(color: AppColors.statusAtendida, texto: 'En atención'),
          ],
        ),
      ),
    );
  }
}

class _LeyendaItem extends StatelessWidget {
  const _LeyendaItem({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, size: 16, color: color),
        const SizedBox(width: 6),
        Text(texto, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

/// Detalle de una alerta al tocar su marcador.
class _DetalleAlerta extends StatelessWidget {
  const _DetalleAlerta({required this.alert});

  final SosAlert alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('dd/MM/yyyy · HH:mm');
    final nombre = (alert.userName != null && alert.userName!.isNotEmpty)
        ? alert.userName!
        : 'Ciudadano';
    final coords =
        '${alert.latitude.toStringAsFixed(5)}, ${alert.longitude.toStringAsFixed(5)}';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nombre, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _Fila(
              icon: Icons.report_gmailerrorred_outlined,
              texto: 'Incidente: ${alert.categoria ?? 'Sin especificar'}',
            ),
            const SizedBox(height: 6),
            _Fila(icon: Icons.flag_outlined, texto: 'Estado: ${alert.status.label}'),
            const SizedBox(height: 6),
            _Fila(icon: Icons.schedule, texto: df.format(alert.timestamp)),
            const SizedBox(height: 6),
            _Fila(icon: Icons.place_outlined, texto: alert.address ?? coords),
          ],
        ),
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.icon, required this.texto});

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(texto)),
      ],
    );
  }
}
