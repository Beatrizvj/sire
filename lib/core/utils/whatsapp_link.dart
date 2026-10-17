import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

import '../../features/users/domain/entities/user_role.dart';

/// Cómo se presenta en el mensaje la autoridad que escribe, según su rol y
/// aldea: "la Alcaldía Auxiliar de La Emboscada", "el COCODE de El Llano" o
/// "la Municipalidad". Sin rol conocido, la Municipalidad.
String remitenteSire(UserRole? rol, String aldea) {
  final a = aldea.trim();
  return switch (rol) {
    UserRole.auxiliatura =>
      a.isEmpty ? 'la Alcaldía Auxiliar' : 'la Alcaldía Auxiliar de $a',
    UserRole.cocode => a.isEmpty ? 'el COCODE' : 'el COCODE de $a',
    _ => 'la Municipalidad',
  };
}

/// Enlace universal y gratuito de WhatsApp (wa.me) para escribirle a un
/// ciudadano sobre su reporte. Deja solo los dígitos del teléfono y, si es un
/// número local de Guatemala (8 dígitos), le antepone el código de país 502.
/// [remitente] es la autoridad que escribe (ver [remitenteSire]).
/// Devuelve null si el teléfono no tiene dígitos.
Uri? enlaceWhatsApp(String telefono, String nombre,
    {String remitente = 'la Municipalidad'}) {
  final digitos = telefono.replaceAll(RegExp(r'\D'), '');
  if (digitos.isEmpty) return null;
  final numero = digitos.length == 8 ? '502$digitos' : digitos;
  final saludo = nombre.trim().isEmpty ? 'Hola' : 'Hola ${nombre.trim()}';
  // "de el COCODE" → "del COCODE".
  final desde = remitente.startsWith('el ')
      ? 'del ${remitente.substring(3)}'
      : 'de $remitente';
  final texto = '$saludo, nos comunicamos $desde (SIRE) respecto '
      'a su reporte.';
  return Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(texto)}');
}

/// Abre el chat de WhatsApp: en la web, en una pestaña nueva; en el móvil,
/// con el manejador nativo (la app de WhatsApp instalada). Devuelve false si el
/// teléfono no es válido o no se pudo abrir.
Future<bool> abrirWhatsApp(String telefono, String nombre,
    {String remitente = 'la Municipalidad'}) async {
  final uri = enlaceWhatsApp(telefono, nombre, remitente: remitente);
  if (uri == null) return false;
  return launchUrl(
    uri,
    mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
}
