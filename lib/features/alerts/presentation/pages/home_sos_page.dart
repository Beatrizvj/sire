import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/services/power_button_bridge.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../incidents/data/incident_category_repository.dart';
import '../../../incidents/domain/incident_category.dart';
import '../../domain/entities/alert_status.dart';
import '../../domain/entities/sos_alert.dart';
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

class _HomeSosPageState extends ConsumerState<HomeSosPage>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _powerSub;
  bool _detectionOn = false;
  bool _togglingDetection = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Escucha los eventos del servicio nativo (3 pulsaciones del botón físico).
    _powerSub = ref.read(powerButtonBridgeProvider).events.listen(
          _onPowerEvent,
          onError: (_) {},
        );
    // Refleja en el switch el estado REAL del servicio (por si ya venía activo).
    _syncDetectionState();
  }

  /// Pone el switch acorde al estado real del servicio nativo (consultado por el
  /// puente). Evita que arranque en OFF cuando la detección ya está corriendo.
  Future<void> _syncDetectionState() async {
    if (_togglingDetection) return;
    final running =
        await ref.read(powerButtonBridgeProvider).isDetectionRunning();
    if (!mounted) return;
    setState(() => _detectionOn = running);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _powerSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver a la app, refresca el Historial (por si el botón físico disparó
    // un SOS mientras estaba en segundo plano).
    if (state == AppLifecycleState.resumed) {
      ref.read(alertsControllerProvider.notifier).refresh();
      _syncDetectionState();
    }
  }

  void _onPowerEvent(String event) {
    if (event != 'sos_triggered') return;
    // El servicio nativo ya capturó el GPS y guardó la alerta en Firestore
    // (funciona con la pantalla apagada / app en segundo plano). Aquí, si la
    // app está abierta, solo refrescamos la lista y avisamos.
    ref.read(alertsControllerProvider.notifier).refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Theme.of(context).colorScheme.error,
          content: const Text('🚨 SOS por botón de encendido registrado'),
        ),
      );
  }

  /// Pide la categoría del incidente antes de enviar el SOS manual, para que la
  /// alerta llegue clasificada (R3). El usuario también puede omitirla.
  Future<void> _onSosPressed() async {
    final categorias = ref.read(categoriasActivasProvider);
    final categoria = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('¿Qué está pasando?',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final c in categorias)
              ListTile(
                leading: const Icon(Icons.report_gmailerrorred_outlined),
                title: Text(c),
                onTap: () => Navigator.pop(sheetCtx, c),
              ),
            ListTile(
              leading: const Icon(Icons.bolt),
              title: const Text('Enviar sin especificar'),
              subtitle: const Text('Emergencia general'),
              onTap: () => Navigator.pop(sheetCtx, categoriaSinEspecificar),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    // Si cerró el panel sin elegir, no se envía nada.
    if (categoria == null) return;
    await _trigger(
      SosSource.screenButton,
      categoria: categoria == categoriaSinEspecificar ? null : categoria,
    );
  }

  Future<void> _trigger(SosSource source, {String? categoria}) async {
    final result = await ref
        .read(alertsControllerProvider.notifier)
        .triggerSos(source, categoria: categoria);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    if (result != null) {
      final alert = result.alert;
      final location = alert.address ??
          '${alert.latitude.toStringAsFixed(5)}, ${alert.longitude.toStringAsFixed(5)}';
      if (result.enCola) {
        // Sin señal: Firestore ya la guardó y la enviará al reconectar.
        messenger.showSnackBar(
          SnackBar(
            content: Text(
                '📶 SOS guardado sin señal. Se enviará en cuanto haya conexión.\n$location'),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text('🚨 SOS enviado · ${source.label}\n$location'),
          ),
        );
      }
    } else {
      final error =
          ref.read(alertsControllerProvider).lastError ?? 'No se pudo enviar el SOS.';
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }


  Future<void> _toggleDetection(bool value) async {
    setState(() => _togglingDetection = true);
    final bridge = ref.read(powerButtonBridgeProvider);
    final permisos = ref.read(permissionServiceProvider);

    var enabled = false;
    String? errorMsg;

    if (value) {
      await permisos.ensureNotifications();
      // OBLIGATORIO en Android 14+: el servicio en primer plano es de tipo
      // "location"; sin permiso de ubicación concedido, arrancarlo hace que el
      // sistema cierre la app. Por eso lo exigimos ANTES de iniciar.
      final ubicacionOk = await permisos.ensureLocationWhenInUse();
      if (!ubicacionOk) {
        errorMsg =
            'Para la detección por botón de encendido necesitas permitir la '
            'ubicación. Actívala en los permisos de la app e intenta de nuevo.';
      } else {
        // Exención de optimización de batería: sin ella el sistema mata el
        // servicio en segundo plano y el botón de encendido deja de escucharse.
        if (!await bridge.isIgnoringBatteryOptimizations()) {
          await bridge.requestIgnoreBatteryOptimizations();
        }
        final user = ref.read(authControllerProvider).user;
        enabled = await bridge.startDetection(
          user?.uid ?? '',
          user?.displayName ?? '',
        );
        if (!enabled) {
          errorMsg =
              'No se pudo iniciar la detección. Requiere un dispositivo '
              'Android real.';
        }
      }
    } else {
      await bridge.stopDetection();
    }

    if (!mounted) return;
    setState(() {
      _togglingDetection = false;
      _detectionOn = value && enabled;
    });

    if (errorMsg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  /// Menú al tocar una alerta del historial: clasificar el incidente y/o
  /// cancelarla (falsa alarma) si aún está abierta.
  Future<void> _onAlertTap(SosAlert alert) async {
    final cancelable = alert.status == AlertStatus.pendiente ||
        alert.status == AlertStatus.atendida;
    final accion = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.label_outline),
              title: Text(alert.categoria == null
                  ? 'Clasificar incidente'
                  : 'Cambiar categoría (${alert.categoria})'),
              onTap: () => Navigator.pop(sheetCtx, 'clasificar'),
            ),
            if (cancelable)
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: const Text('Cancelar alerta (falsa alarma)'),
                onTap: () => Navigator.pop(sheetCtx, 'cancelar'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (accion == 'clasificar') {
      await _clasificar(alert);
    } else if (accion == 'cancelar') {
      await _confirmarCancelacion(alert);
    }
  }

  Future<void> _clasificar(SosAlert alert) async {
    final categorias = ref.read(categoriasActivasProvider);
    final elegida = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text('Tipo de incidente',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final c in categorias)
              ListTile(
                leading: const Icon(Icons.report_gmailerrorred_outlined),
                title: Text(c),
                onTap: () => Navigator.pop(sheetCtx, c),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (elegida == null) return;
    try {
      await ref
          .read(alertsControllerProvider.notifier)
          .updateCategoria(alert.id, elegida);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Clasificada como "$elegida".')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo clasificar: $e')));
    }
  }

  Future<void> _confirmarCancelacion(SosAlert alert) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cancelar esta alerta?'),
        content: const Text(
          'Se marcará como "Falsa alarma". Úsalo si la enviaste por error.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ref
          .read(alertsControllerProvider.notifier)
          .updateStatus(alert.id, AlertStatus.falsaAlarma);
      await ref.read(alertsControllerProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Alerta cancelada (falsa alarma).')),
        );
    } catch (e) {
      if (!mounted) return;
      // El caso típico: la alerta se envió con poca señal y todavía no termina
      // de subir al servidor, así que aún no se puede cancelar. Se lo explicamos
      // en claro (en vez del error técnico) y le pedimos reintentar.
      final s = e.toString();
      final aunEnviando = s.contains('permission-denied') ||
          s.contains('not-found') ||
          s.contains('unavailable');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(aunEnviando
              ? 'La alerta todavía se está enviando (puede ser por poca señal). '
                  'Espera unos segundos e inténtalo de nuevo.'
              : 'No se pudo cancelar: $e'),
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
        // Sin "Borrar historial": las alertas son registros de emergencia que la
        // Municipalidad necesita (frecuencia de alertas — línea 501 del PG2 — y
        // bitácora de auditoría RF-10). El ciudadano no debe poder eliminarlas
        // del sistema. La limpieza de datos de prueba se hace por otra vía.
        title: const Text(AppConfig.appName),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          Center(
            child: SosButton(
              isSending: state.isSending,
              onPressed: _onSosPressed,
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
            ...state.alerts.map((alert) => AlertTile(
                  alert: alert,
                  onTap: () => _onAlertTap(alert),
                )),
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
