import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

/// Abre Google Maps en modo navegación ("Cómo llegar") hacia [lat], [lng],
/// con el esquema de URL universal y gratuito de Google Maps.
/// - Web: en una pestaña nueva, sin salir del panel.
/// - Móvil: con el manejador nativo de enlaces (la app de Google Maps si está
///   instalada; si no, el navegador).
/// Devuelve false si no se pudo abrir.
Future<bool> abrirComoLlegar(double lat, double lng) {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
  );
  return launchUrl(
    uri,
    mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
}
