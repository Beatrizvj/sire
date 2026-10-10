import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

/// Enlace universal y gratuito de WhatsApp (wa.me) para escribirle a un
/// ciudadano sobre su reporte. Deja solo los dígitos del teléfono y, si es un
/// número local de Guatemala (8 dígitos), le antepone el código de país 502.
/// Devuelve null si el teléfono no tiene dígitos.
Uri? enlaceWhatsApp(String telefono, String nombre) {
  final digitos = telefono.replaceAll(RegExp(r'\D'), '');
  if (digitos.isEmpty) return null;
  final numero = digitos.length == 8 ? '502$digitos' : digitos;
  final saludo = nombre.trim().isEmpty ? 'Hola' : 'Hola ${nombre.trim()}';
  final texto = '$saludo, nos comunicamos de la Municipalidad (SIRE) respecto '
      'a su reporte.';
  return Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(texto)}');
}

/// Abre el chat de WhatsApp: en la web, en una pestaña nueva; en el móvil,
/// con el manejador nativo (la app de WhatsApp instalada). Devuelve false si el
/// teléfono no es válido o no se pudo abrir.
Future<bool> abrirWhatsApp(String telefono, String nombre) async {
  final uri = enlaceWhatsApp(telefono, nombre);
  if (uri == null) return false;
  return launchUrl(
    uri,
    mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
}
