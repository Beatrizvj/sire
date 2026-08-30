import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// RF-13: ventana de confirmación/cancelación antes de difundir un SOS enviado
/// desde el botón EN PANTALLA. Muestra una cuenta regresiva de [segundos]; el
/// ciudadano puede CANCELAR (no se envía nada) o "Enviar ahora" (sin esperar).
/// Al agotarse el tiempo, se envía. Espeja la ventana del botón de encendido
/// (CANCEL_WINDOW_SECONDS en PowerButtonService.kt) para una UX consistente.
///
/// Devuelve `true` si se debe enviar el SOS; `false` si se canceló (incluye el
/// botón "Atrás" del sistema, que se trata como cancelación segura).
Future<bool> showSosCountdown(
  BuildContext context, {
  required int segundos,
}) async {
  final enviar = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SosCountdownDialog(segundos: segundos),
  );
  return enviar ?? false;
}

class _SosCountdownDialog extends StatefulWidget {
  const _SosCountdownDialog({required this.segundos});

  final int segundos;

  @override
  State<_SosCountdownDialog> createState() => _SosCountdownDialogState();
}

class _SosCountdownDialogState extends State<_SosCountdownDialog> {
  late int _restante = widget.segundos;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _restante--);
      if (_restante <= 0) {
        t.cancel();
        Navigator.of(context).pop(true); // se agotó el tiempo → enviar
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progreso = widget.segundos == 0 ? 0.0 : _restante / widget.segundos;
    return AlertDialog(
      title: const Text('Enviando SOS…'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progreso,
                    strokeWidth: 8,
                    color: AppColors.emergency,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
                Text(
                  '$_restante',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.emergency,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tu alerta se enviará en $_restante s.\nCancela si fue un error.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.close),
              label: const Text('CANCELAR'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enviar ahora'),
          ),
        ],
      ),
    );
  }
}
