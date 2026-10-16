import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/link.dart';

import '../../../../core/utils/como_llegar.dart';
import '../../domain/entities/sos_alert.dart';
import '../providers/alerts_providers.dart';

/// La versión más reciente de [alerta] en el flujo en tiempo real (para que
/// una hoja abierta siga la ubicación en vivo); si no está, la recibida.
SosAlert alertaVigente(WidgetRef ref, SosAlert alerta) {
  final todas = ref.watch(allAlertsProvider).asData?.value;
  if (todas == null) return alerta;
  for (final a in todas) {
    if (a.id == alerta.id) return a;
  }
  return alerta;
}

/// Indicador "En vivo · hace 8 s · ±10 m". Se refresca solo cada 5 s para que
/// la antigüedad avance aunque no llegue una ubicación nueva.
class IndicadorEnVivo extends StatefulWidget {
  const IndicadorEnVivo({super.key, required this.alerta, this.compacto = false});

  final SosAlert alerta;
  final bool compacto;

  @override
  State<IndicadorEnVivo> createState() => _IndicadorEnVivoState();
}

class _IndicadorEnVivoState extends State<IndicadorEnVivo> {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(
        const Duration(seconds: 5), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alerta;
    if (!a.tieneUbicacionEnVivo) return const SizedBox.shrink();
    final en = a.ubicacionActualEn;
    // "En vivo" solo si el seguimiento sigue activo (alerta abierta, sin
    // cortar, < 2 h) y el último punto es reciente; si no, última ubicación.
    final vivo = a.ubicacionEnVivoActiva();
    final color = vivo ? const Color(0xFF2E7D32) : const Color(0xFF8D6E63);
    final partes = [
      vivo ? 'En vivo' : 'Última ubicación',
      if (en != null) haceCuanto(en),
      if (a.precisionActual != null) '±${a.precisionActual!.round()} m',
      if (a.seguimientoDetenidoEn != null) 'el ciudadano dejó de compartir',
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(vivo ? Icons.my_location : Icons.location_history,
            size: widget.compacto ? 14 : 18, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            partes.join(' · '),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: widget.compacto ? 12 : 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// Botón "Cómo llegar": abre Google Maps hacia donde está la persona AHORA
/// (ubicación en vivo si existe; si no, la del SOS).
class BotonComoLlegar extends StatelessWidget {
  const BotonComoLlegar({super.key, required this.alerta});

  final SosAlert alerta;

  @override
  Widget build(BuildContext context) {
    if (!alerta.tieneUbicacionParaLlegar) return const SizedBox.shrink();
    final etiqueta = Text(alerta.tieneUbicacionEnVivo
        ? 'Cómo llegar (ubicación actual)'
        : 'Cómo llegar');
    // Web: un enlace REAL (Link) en pestaña nueva; abrirlo por código tras un
    // await el navegador lo bloquea como ventana emergente.
    if (kIsWeb) {
      return Link(
        uri: enlaceComoLlegar(
            alerta.latitudParaLlegar, alerta.longitudParaLlegar),
        target: LinkTarget.blank,
        builder: (context, abrir) => FilledButton.icon(
          onPressed: abrir,
          icon: const Icon(Icons.directions),
          label: etiqueta,
        ),
      );
    }
    return FilledButton.icon(
      onPressed: () async {
        final ok = await abrirComoLlegar(
            alerta.latitudParaLlegar, alerta.longitudParaLlegar);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir Google Maps.')),
          );
        }
      },
      icon: const Icon(Icons.directions),
      label: etiqueta,
    );
  }
}
