import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

/// Política de privacidad publicada en Firebase Hosting. Google Play exige
/// que también se pueda abrir desde la app (registro y perfil).
final Uri kPoliticaPrivacidad =
    Uri.parse('https://sire-app-179d3.web.app/privacidad.html');

/// Abre la política: en la web, en una pestaña nueva; en el móvil, en el
/// navegador. Devuelve false si no se pudo abrir.
Future<bool> abrirPoliticaPrivacidad() => launchUrl(
      kPoliticaPrivacidad,
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
