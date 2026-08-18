import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/alert_status.dart';
import '../../domain/entities/sos_alert.dart';
import '../providers/alerts_providers.dart';

/// Reproductor ÚNICO de la alarma, compartido por [NewAlertAlarm] (suena la
/// sirena al entrar una alerta) y el botón "Activar sonido" del panel (que lo
/// desbloquea con un gesto del usuario). Así el navegador habilita el MISMO
/// reproductor que después suena las alertas.
final alarmPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer(playerId: 'sire_alarm');
  ref.onDispose(player.dispose);
  return player;
});

/// RF-14 · Vigila las alertas y, cuando entra una **nueva**, dispara una alarma
/// sonora (sirena en bucle) y un aviso visual rojo sobre el panel.
///
/// Se coloca como hijo de un [Stack] que cubre el panel: mientras no hay alarma
/// activa ocupa cero espacio y no bloquea la interacción. Solo suena por las
/// alertas que llegan **después** de abrir el panel (las ya existentes al cargar
/// se toman como "conocidas" para no sonar de golpe).
class NewAlertAlarm extends ConsumerStatefulWidget {
  const NewAlertAlarm({super.key, this.onVer});

  /// Acción del botón "Ver" (p. ej. saltar a la sección Alertas).
  final VoidCallback? onVer;

  @override
  ConsumerState<NewAlertAlarm> createState() => _NewAlertAlarmState();
}

class _NewAlertAlarmState extends ConsumerState<NewAlertAlarm>
    with SingleTickerProviderStateMixin {
  late final AudioPlayer _player;
  final Set<String> _conocidas = {};
  bool _primeraCarga = true;
  SosAlert? _activa;
  Timer? _autoStop;

  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _player = ref.read(alarmPlayerProvider);
    _player.setReleaseMode(ReleaseMode.loop);
  }

  @override
  void dispose() {
    _autoStop?.cancel();
    _blink.dispose();
    // El reproductor lo administra alarmPlayerProvider; no se libera aquí.
    super.dispose();
  }

  Future<void> _sonar() async {
    _autoStop?.cancel();
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/alerta.wav'));
      // Freno de seguridad: la sirena no suena más de 20 s aunque nadie la
      // silencie; el aviso visual permanece hasta que la autoridad actúe.
      _autoStop = Timer(const Duration(seconds: 20), () => _player.stop());
    } catch (_) {
      // El navegador puede bloquear el audio hasta el primer clic del usuario;
      // el aviso visual sigue funcionando de todos modos.
    }
  }

  Future<void> _silenciar() async {
    _autoStop?.cancel();
    try {
      await _player.stop();
    } catch (_) {}
    if (mounted) setState(() => _activa = null);
  }

  void _onAlerts(
    AsyncValue<List<SosAlert>>? prev,
    AsyncValue<List<SosAlert>> next,
  ) {
    final lista = next.asData?.value;
    if (lista == null) return;

    final pendientes =
        lista.where((a) => a.status == AlertStatus.pendiente).toList();
    final idsPendientes = pendientes.map((a) => a.id).toSet();

    // Primera emisión: registrar lo que ya había sin sonar.
    if (_primeraCarga) {
      _conocidas
        ..clear()
        ..addAll(idsPendientes);
      _primeraCarga = false;
      return;
    }

    // Alertas pendientes que no habíamos visto todavía.
    final nuevas = pendientes.where((a) => !_conocidas.contains(a.id)).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Actualizar el registro (solo las que siguen pendientes).
    _conocidas
      ..clear()
      ..addAll(idsPendientes);

    if (nuevas.isNotEmpty) {
      setState(() => _activa = nuevas.first);
      _sonar();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<SosAlert>>>(allAlertsProvider, _onAlerts);

    final alerta = _activa;
    if (alerta == null) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: _Banner(
                alerta: alerta,
                blink: _blink,
                onVer: widget.onVer == null
                    ? null
                    : () {
                        _silenciar();
                        widget.onVer!();
                      },
                onSilenciar: _silenciar,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.alerta,
    required this.blink,
    required this.onVer,
    required this.onSilenciar,
  });

  final SosAlert alerta;
  final Animation<double> blink;
  final VoidCallback? onVer;
  final VoidCallback onSilenciar;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy · HH:mm');
    final nombre = (alerta.userName != null && alerta.userName!.isNotEmpty)
        ? alerta.userName!
        : 'Ciudadano';
    final ubicacion = alerta.address ??
        (alerta.latitude == 0 && alerta.longitude == 0
            ? 'Ubicación no registrada'
            : '${alerta.latitude.toStringAsFixed(5)}, '
                '${alerta.longitude.toStringAsFixed(5)}');
    final categoria = alerta.categoria ?? 'Sin especificar';

    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(16),
      color: const Color(0xFFBA1A1A),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FadeTransition(
                  opacity: blink,
                  child: const Icon(Icons.notifications_active,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '🚨 NUEVA ALERTA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$nombre · $categoria',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$ubicacion\n${df.format(alerta.timestamp)}',
              style: const TextStyle(color: Color(0xFFFFE0DE), fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (onVer != null) ...[
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFBA1A1A),
                      ),
                      onPressed: onVer,
                      icon: const Icon(Icons.visibility),
                      label: const Text('Ver'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                    ),
                    onPressed: onSilenciar,
                    icon: const Icon(Icons.volume_off),
                    label: const Text('Silenciar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
