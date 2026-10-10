import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

/// URL universal y gratuita de Google Maps en modo navegación ("Cómo llegar")
/// hacia [lat], [lng].
Uri enlaceComoLlegar(double lat, double lng) => Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );

/// Abre Google Maps en modo navegación hacia [lat], [lng].
/// - Web: en una pestaña nueva, sin salir del panel. (En el panel se prefiere
///   el widget `Link` con [enlaceComoLlegar]: es un enlace real que el
///   navegador nunca bloquea como ventana emergente.)
/// - Móvil: con el manejador nativo de enlaces (la app de Google Maps si está
///   instalada; si no, el navegador).
/// Devuelve false si no se pudo abrir.
Future<bool> abrirComoLlegar(double lat, double lng) {
  return launchUrl(
    enlaceComoLlegar(lat, lng),
    mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
}
