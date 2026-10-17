import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../core/config/version_app.dart';
import '../../../../core/web/navegador.dart';

/// Franja "Hay una versión nueva del panel" (solo web).
///
/// El navegador puede seguir usando el panel en caché después de publicar una
/// versión nueva. Al abrir y cada [_intervalo] se consulta `/version.json`
/// (servido sin caché) y, si su `build_number` es mayor que
/// [kNumeroCompilacion], se ofrece recargar. No recarga solo para no
/// interrumpir a quien atiende una alerta.
class AvisoVersionNueva extends StatefulWidget {
  const AvisoVersionNueva({super.key});

  @override
  State<AvisoVersionNueva> createState() => _AvisoVersionNuevaState();
}

class _AvisoVersionNuevaState extends State<AvisoVersionNueva> {
  static const _intervalo = Duration(minutes: 5);

  final _dio = Dio();
  Timer? _reloj;
  int? _nueva;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    _revisar();
    _reloj = Timer.periodic(_intervalo, (_) => _revisar());
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _dio.close();
    super.dispose();
  }

  Future<void> _revisar() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '/version.json',
        queryParameters: {'t': DateTime.now().millisecondsSinceEpoch},
      );
      final n = int.tryParse('${r.data?['build_number']}');
      if (n != null && n > kNumeroCompilacion && mounted) {
        setState(() => _nueva = n);
      }
    } catch (_) {
      // Sin conexión: se vuelve a intentar en la próxima revisión.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_nueva == null) return const SizedBox.shrink();
    return Material(
      color: const Color(0xFFFFF3E0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.system_update_alt, color: Color(0xFFE65100)),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Hay una versión nueva del panel. Actualiza para ver los '
                'últimos cambios.',
                style: TextStyle(color: Color(0xFF5D4037)),
              ),
            ),
            FilledButton(
              onPressed: recargarPagina,
              child: const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }
}
