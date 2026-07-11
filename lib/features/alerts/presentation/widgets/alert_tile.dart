import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/sos_alert.dart';
import '../../domain/entities/sos_source.dart';

/// Fila del historial de alertas.
class AlertTile extends StatelessWidget {
  const AlertTile({super.key, required this.alert});

  final SosAlert alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd/MM/yyyy · HH:mm:ss');
    final coords =
        '${alert.latitude.toStringAsFixed(5)}, ${alert.longitude.toStringAsFixed(5)}';
    final accuracy =
        alert.accuracy != null ? ' · ±${alert.accuracy!.toStringAsFixed(0)} m' : '';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.errorContainer,
          child: Icon(
            alert.source == SosSource.powerButton
                ? Icons.power_settings_new
                : Icons.sos,
            color: scheme.onErrorContainer,
          ),
        ),
        title: Text(alert.address ?? coords),
        subtitle: Text(
          '${dateFormat.format(alert.timestamp)}\n'
          '${alert.source.label} · $coords$accuracy',
        ),
        isThreeLine: true,
      ),
    );
  }
}
