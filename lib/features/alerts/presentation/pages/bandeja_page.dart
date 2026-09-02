import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../users/domain/entities/app_user.dart';
import '../../../users/presentation/pages/approvals_page.dart';
import '../../../users/presentation/pages/users_management_page.dart';
import '../../../users/presentation/providers/approvals_providers.dart';
import '../../../users/presentation/providers/users_providers.dart';
import '../../domain/entities/alert_status.dart';
import '../../domain/entities/sos_alert.dart';
import '../../domain/entities/sos_source.dart';
import '../providers/alerts_providers.dart';
import '../widgets/alert_status_chip.dart';

/// Coordenadas legibles; "Ubicación no registrada" si la alerta se guardó sin GPS.
String _coords(SosAlert alert) => (alert.latitude == 0 && alert.longitude == 0)
    ? 'Ubicación no registrada'
    : '${alert.latitude.toStringAsFixed(5)}, ${alert.longitude.toStringAsFixed(5)}';

/// Bandeja de emergencias para COCODE / Municipalidad.
///
/// Muestra en tiempo real todas las alertas de la comunidad y permite
/// atenderlas, resolverlas o marcarlas como falsa alarma. Se apoya en las
/// reglas de Firestore, que autorizan a estos roles a leer y actualizar.
class BandejaPage extends ConsumerWidget {
  const BandejaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(allAlertsProvider);
    final autoridad = ref.watch(currentUserProfileProvider).asData?.value;
    // Solicitudes pendientes que le tocan a esta autoridad (para el distintivo).
    final usuarios = ref.watch(allUsersProvider).asData?.value;
    final pendientes = (usuarios != null && autoridad != null)
        ? pendientesPara(usuarios, autoridad).length
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bandeja de emergencias'),
        actions: [
          IconButton(
            tooltip: 'Aprobaciones',
            icon: Badge(
              isLabelVisible: pendientes > 0,
              label: Text('$pendientes'),
              child: const Icon(Icons.how_to_reg_outlined),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ApprovalsPage(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Gestión de usuarios',
            icon: const Icon(Icons.manage_accounts),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const UsersManagementPage(),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: alertsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorView(
              message: '$e',
              onRetry: () => ref.invalidate(allAlertsProvider),
            ),
            data: (alerts) => alerts.isEmpty
                ? const _EmptyView()
                : _AlertsList(alerts: alerts),
          ),
        ),
      ),
    );
  }
}

class _AlertsList extends StatelessWidget {
  const _AlertsList({required this.alerts});

  final List<SosAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final pendientes =
        alerts.where((a) => a.status == AlertStatus.pendiente).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _ResumenBar(total: alerts.length, pendientes: pendientes),
        const SizedBox(height: 16),
        for (final alert in alerts)
          _EmergencyTile(
            alert: alert,
            onTap: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (_) => _AccionesSheet(alert: alert),
            ),
          ),
      ],
    );
  }
}

class _EmergencyTile extends StatelessWidget {
  const _EmergencyTile({required this.alert, required this.onTap});

  final SosAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final df = DateFormat('dd/MM/yyyy · HH:mm');
    final coords = _coords(alert);
    final nombre = (alert.userName != null && alert.userName!.isNotEmpty)
        ? alert.userName!
        : 'Ciudadano';
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.errorContainer,
          child: Icon(
            alert.source == SosSource.powerButton
                ? Icons.power_settings_new
                : Icons.sos,
            color: scheme.onErrorContainer,
          ),
        ),
        title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            _CategoriaChip(categoria: alert.categoria),
            const SizedBox(height: 6),
            Text('${df.format(alert.timestamp)}\n${alert.address ?? coords}'),
          ],
        ),
        trailing: AlertStatusChip(status: alert.status),
        isThreeLine: true,
      ),
    );
  }
}

class _AccionesSheet extends ConsumerWidget {
  const _AccionesSheet({required this.alert});

  final SosAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final df = DateFormat('dd/MM/yyyy · HH:mm');
    final coords = _coords(alert);
    final nombre = (alert.userName != null && alert.userName!.isNotEmpty)
        ? alert.userName!
        : 'Ciudadano';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(nombre, style: theme.textTheme.titleLarge),
                ),
                AlertStatusChip(status: alert.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${alert.source.label} · ${df.format(alert.timestamp)}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.report_gmailerrorred_outlined,
              text: 'Incidente: ${alert.categoria ?? 'Sin especificar'}',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.place_outlined,
              text: alert.address ?? 'Sin dirección disponible',
            ),
            const SizedBox(height: 8),
            _InfoRow(icon: Icons.my_location, text: coords),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _llamarCiudadano(context, ref),
              icon: const Icon(Icons.call),
              label: const Text('Llamar al ciudadano'),
            ),
            const Divider(height: 32),
            Text('Cambiar estado', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () =>
                        _cambiar(context, ref, AlertStatus.atendida),
                    icon: const Icon(Icons.engineering),
                    label: const Text('Atender'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        _cambiar(context, ref, AlertStatus.resuelta),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Resolver'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _cambiar(context, ref, AlertStatus.falsaAlarma),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Marcar como falsa alarma'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cambiar(
    BuildContext context,
    WidgetRef ref,
    AlertStatus status,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(alertsControllerProvider.notifier)
          .updateStatus(alert.id, status);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Alerta marcada como ${status.label}.')),
      );
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    }
  }

  /// Busca el teléfono del ciudadano en su ficha y abre el marcador (CU-06,
  /// llamada directa). En el teléfono de la autoridad marca directo.
  Future<void> _llamarCiudadano(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final usuarios =
        ref.read(allUsersProvider).asData?.value ?? const <AppUser>[];
    var telefono = '';
    for (final u in usuarios) {
      if (u.id == alert.userId) {
        telefono = u.telefono;
        break;
      }
    }
    final limpio = telefono.replaceAll(RegExp(r'[^0-9+]'), '');
    if (limpio.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Este ciudadano no tiene teléfono registrado.')));
      return;
    }
    final ok = await launchUrl(Uri(scheme: 'tel', path: limpio));
    if (!ok) {
      messenger.showSnackBar(SnackBar(
          content: Text('No se pudo abrir el marcador para $limpio.')));
    }
  }
}

class _ResumenBar extends StatelessWidget {
  const _ResumenBar({required this.total, required this.pendientes});

  final int total;
  final int pendientes;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _Metric(
            label: 'Alertas',
            value: '$total',
            icon: Icons.notifications_active_outlined,
            color: scheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _Metric(
            label: 'Pendientes',
            value: '$pendientes',
            icon: Icons.hourglass_bottom,
            color: scheme.error,
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

/// Chip con el tipo de incidente (Robo, Asalto, Persona sospechosa) de la alerta.
/// Cumple con la síntesis 4.5.1 del PG2: la autoridad debe visualizar de
/// inmediato el tipo de incidencia. "Sin especificar" cuando aún no se clasifica.
class _CategoriaChip extends StatelessWidget {
  const _CategoriaChip({required this.categoria});

  final String? categoria;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sinEspecificar = categoria == null || categoria!.isEmpty;
    final (bg, fg) = sinEspecificar
        ? (scheme.surfaceContainerHighest, scheme.onSurfaceVariant)
        : (scheme.errorContainer, scheme.onErrorContainer);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.report_gmailerrorred_outlined, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            sinEspecificar ? 'Sin especificar' : categoria!,
            style:
                TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('No hay alertas', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Cuando un ciudadano envíe un SOS, aparecerá aquí en tiempo real.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'No se pudieron cargar las alertas',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
