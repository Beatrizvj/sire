import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/alert_status.dart';

/// Color de fondo y de texto de cada estado de alerta.
///
/// Fuente ÚNICA de la paleta de estados: la usan la app móvil (Bandeja e
/// historial) y el panel web, así los colores coinciden siempre en los dos.
({Color bg, Color fg}) alertStatusColors(AlertStatus status) => switch (status) {
      AlertStatus.pendiente =>
        (bg: AppColors.statusPendiente, fg: const Color(0xFF412402)),
      AlertStatus.atendida => (bg: AppColors.statusAtendida, fg: Colors.white),
      AlertStatus.resuelta => (bg: AppColors.statusResuelta, fg: Colors.white),
      AlertStatus.falsaAlarma =>
        (bg: AppColors.statusFalsaAlarma, fg: Colors.white),
    };

/// Chip de estado reutilizable, con el mismo aspecto en la app y el panel.
class AlertStatusChip extends StatelessWidget {
  const AlertStatusChip({super.key, required this.status});

  final AlertStatus status;

  @override
  Widget build(BuildContext context) {
    final c = alertStatusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: c.fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
