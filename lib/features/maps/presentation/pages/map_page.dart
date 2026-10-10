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
/// Encuadre inicial del mapa cuando aún no hay alertas con ubicación.
const LatLng _centroMunicipio = LatLng(14.8726, -91.6009);

/// Máximo de marcadores dibujados a la vez, para que el mapa no se sature cuando
/// hay muchas alertas activas (se muestran las más recientes).
const int _maxMarcadores = 80;

/// Máximo de puntos considerados para el mapa de calor.
const int _maxPuntosCalor = 500;

/// Vista del mapa: mapa de calor (densidad de incidentes) o marcadores puntuales.
enum _VistaMapa { calor, marcadores }

/// Mapa de alertas para las autoridades (COCODE / Municipalidad) sobre
/// OpenStreetMap. Ofrece dos vistas (RF mapa de calor):
///  • **Calor**: densidad de incidentes: las zonas con más alertas se ven más
///    intensas (círculos translúcidos superpuestos). Usa todo el historial
///    reciente con ubicación válida.
///  • **Marcadores**: un pin por alerta ACTIVA (pendiente o en atención), con
///    detalle al tocarlo. Ambas vistas se actualizan en vivo.
class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  _VistaMapa _vista = _VistaMapa.calor;

  bool _conUbicacion(SosAlert a) => !(a.latitude == 0 && a.longitude == 0);

  LatLng _centro(List<SosAlert> puntos) {
    if (puntos.isEmpty) return _centroMunicipio;
    final lat =
        puntos.map((a) => a.latitude).reduce((x, y) => x + y) / puntos.length;
    final lng =
        puntos.map((a) => a.longitude).reduce((x, y) => x + y) / puntos.length;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final alertsAsync = ref.watch(allAlertsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de alertas'),
        actions: [
          IconButton(
            tooltip: 'Mapa de calor',
            isSelected: _vista == _VistaMapa.calor,
            icon: const Icon(Icons.blur_on),
            onPressed: () => setState(() => _vista = _VistaMapa.calor),
          ),
          IconButton(
            tooltip: 'Marcadores',
            isSelected: _vista == _VistaMapa.marcadores,
            icon: const Icon(Icons.place_outlined),
            onPressed: () => setState(() => _vista = _VistaMapa.marcadores),
          ),
          const SizedBox(width: 4),
        ],
      ),
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
          // Puntos para el mapa de calor: TODO el historial reciente con
          // ubicación válida (densidad de incidentes por zona).
          final puntosCalor =
              alerts.where(_conUbicacion).take(_maxPuntosCalor).toList();

          // Marcadores: solo alertas ACTIVAS (pendiente o en atención) con
          // ubicación, de la más reciente a la más antigua.
          final activas = alerts
              .where((a) =>
                  (a.status == AlertStatus.pendiente ||
                      a.status == AlertStatus.atendida) &&
                  _conUbicacion(a))
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          final esCalor = _vista == _VistaMapa.calor;
          final base = esCalor ? puntosCalor : activas;
          final vacio = base.isEmpty;

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: _centro(base),
                  initialZoom: esCalor ? 13 : 14,
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
                  if (esCalor)
                    CircleLayer(circles: _circulosCalor(puntosCalor))
                  else
                    MarkerLayer(markers: _marcadores(activas)),
                ],
              ),
              if (vacio) const _SinAlertas(),
              Positioned(
                left: 12,
                bottom: 12,
                child: esCalor ? const _LeyendaCalor() : const _LeyendaPines(),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Capa de calor: densidad geográfica de incidentes. Cada punto aporta un
  /// círculo cuyo color va de ámbar (poca concentración) a rojo (foco crítico)
  /// según cuántos incidentes haya en su vecindad (300 m); al superponerse, las
  /// zonas con más robos se ven más intensas. Mismo criterio que la consola web.
  List<CircleMarker> _circulosCalor(List<SosAlert> incidentes) {
    const radioVecindadM = 300.0;
    const distancia = Distance();
    final puntos = [
      for (final a in incidentes) LatLng(a.latitude, a.longitude),
    ];
    final densidad = <int>[];
    for (final p in puntos) {
      var cerca = 0;
      for (final q in puntos) {
        if (distancia(p, q) <= radioVecindadM) cerca++;
      }
      densidad.add(cerca);
    }
    final maxD =
        densidad.isEmpty ? 1 : densidad.reduce((a, b) => a > b ? a : b);
    // Se pintan de menor a mayor densidad para que los focos queden encima.
    final orden = [for (var i = 0; i < puntos.length; i++) i]
      ..sort((a, b) => densidad[a].compareTo(densidad[b]));
    return [
      for (final i in orden)
        CircleMarker(
          point: puntos[i],
          radius: 220,
          useRadiusInMeter: true,
          color: _colorCalor(densidad[i] / maxD).withValues(alpha: 0.28),
          borderStrokeWidth: 0,
        ),
    ];
  }

  /// Gradiente de calor: ámbar → naranja → rojo según la densidad normalizada.
  static Color _colorCalor(double t) {
    const ambar = Color(0xFFFFC107);
    const naranja = Color(0xFFEF6C00);
    const rojo = Color(0xFFD32F2F);
    return t <= 0.5
        ? Color.lerp(ambar, naranja, t / 0.5) ?? naranja
        : Color.lerp(naranja, rojo, (t - 0.5) / 0.5) ?? rojo;
  }

  List<Marker> _marcadores(List<SosAlert> activas) => [
        for (final a in activas.take(_maxMarcadores))
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
      ];

  void _mostrarDetalle(BuildContext context, SosAlert alert) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _DetalleAlerta(alert: alert),
    );
  }
}

/// Aviso central cuando no hay datos que mostrar en la vista actual.
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
              Text('No hay alertas con ubicación que mostrar.'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Leyenda del mapa de calor.
class _LeyendaCalor extends StatelessWidget {
  const _LeyendaCalor();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Densidad de incidentes',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    gradient: const LinearGradient(colors: [
                      Color(0xFFFFC107),
                      Color(0xFFEF6C00),
                      Color(0xFFD32F2F),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('menos → más', style: TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Leyenda de colores de los marcadores (vista de pines).
class _LeyendaPines extends StatelessWidget {
  const _LeyendaPines();

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
