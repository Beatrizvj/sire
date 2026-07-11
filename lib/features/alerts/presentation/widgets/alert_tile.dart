import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/alert_status.dart';
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
    final accuracy = alert.accuracy != null
        ? ' · ±${alert.accuracy!.toStringAsFixed(0)} m'
        : '';

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
        trailing: _StatusChip(status: alert.status),
        isThreeLine: true,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AlertStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      AlertStatus.pendiente => (scheme.errorContainer, scheme.onErrorContainer),
      AlertStatus.atendida => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      AlertStatus.resuelta => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      AlertStatus.falsaAlarma => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
