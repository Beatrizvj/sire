import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/power_button_bridge.dart';
import '../../domain/entities/sos_source.dart';
import '../providers/alerts_providers.dart';
import '../widgets/alert_tile.dart';
import '../widgets/sos_button.dart';

/// Pantalla principal: botón SOS, activación de la detección por botón físico
/// e historial de alertas.
class HomeSosPage extends ConsumerStatefulWidget {
  const HomeSosPage({super.key});

  @override
  ConsumerState<HomeSosPage> createState() => _HomeSosPageState();
}

class _HomeSosPageState extends ConsumerState<HomeSosPage> {
  StreamSubscription<String>? _powerSub;
  bool _detectionOn = false;
  bool _togglingDetection = false;

  @override
  void initState() {
    super.initState();
    // Escucha los eventos del servicio nativo (3 pulsaciones del botón físico).
    _powerSub = ref.read(powerButtonBridgeProvider).events.listen(
          _onPowerEvent,
          onError: (_) {},
        );
  }

  @override
  void dispose() {
    _powerSub?.cancel();
    super.dispose();
  }

  void _onPowerEvent(String event) {
    if (event == 'sos_triggered') {
      _trigger(SosSource.powerButton);
    }
  }

  Future<void> _trigger(SosSource source) async {
    final alert =
        await ref.read(alertsControllerProvider.notifier).triggerSos(source);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    if (alert != null) {
      final location = alert.address ??
          '${alert.latitude.toStringAsFixed(5)}, ${alert.longitude.toStringAsFixed(5)}';
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: Text('🚨 SOS enviado · ${source.label}\n$location'),
        ),
      );
    } else {
      final error =
          ref.read(alertsControllerProvider).lastError ?? 'No se pudo enviar el SOS.';
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _toggleDetection(bool value) async {
    setState(() => _togglingDetection = true);
    final bridge = ref.read(powerButtonBridgeProvider);

    var enabled = false;
    if (value) {
      await ref.read(permissionServiceProvider).ensureNotifications();
      enabled = await bridge.startDetection();
    } else {
      await bridge.stopDetection();
    }

    if (!mounted) return;
    setState(() {
      _togglingDetection = false;
      _detectionOn = value && enabled;
    });

    if (value && !enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo iniciar la detección. Requiere un dispositivo Android real.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(alertsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.appName),
        actions: [
          if (state.alerts.isNotEmpty)
            IconButton(
              tooltip: 'Borrar historial',
              onPressed: () =>
                  ref.read(alertsControllerProvider.notifier).clearHistory(),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          Center(
            child: SosButton(
              isSending: state.isSending,
              onPressed: () => _trigger(SosSource.screenButton),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            state.isSending
                ? 'Obteniendo tu ubicación…'
                : 'Mantén la calma. Pulsa SOS para enviar tu ubicación.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          _DetectionCard(
            value: _detectionOn,
            busy: _togglingDetection,
            onChanged: _toggleDetection,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Historial', style: theme.textTheme.titleMedium),
              const Spacer(),
              Text('${state.alerts.length}',
                  style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 8),
          if (state.alerts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Aún no has enviado alertas.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            ...state.alerts.map((alert) => AlertTile(alert: alert)),
        ],
      ),
    );
  }
}

class _DetectionCard extends StatelessWidget {
  const _DetectionCard({
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.power_settings_new),
            title: const Text('Detección por botón de encendido'),
            subtitle: Text(
              'Pulsa el botón de encendido ${AppConfig.sosButtonPresses} veces '
              'en ${AppConfig.sosDetectionWindow.inSeconds} s para enviar un SOS.',
            ),
            value: value,
            onChanged: busy ? null : onChanged,
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
