import 'package:flutter_test/flutter_test.dart';
import 'package:sire/core/utils/whatsapp_link.dart';

/// Enlace wa.me para escribir al ciudadano: limpieza del número y prefijo 502.
void main() {
  test('número local de 8 dígitos con guiones/espacios → 502 + dígitos', () {
    final uri = enlaceWhatsApp('3282-8081 ', 'Ana');
    expect(uri.toString(), startsWith('https://wa.me/50232828081?text='));
    expect(Uri.decodeComponent(uri!.query),
        contains('Hola Ana, nos comunicamos de la Municipalidad (SIRE)'));
  });

  test('número que ya trae el código de país no se duplica', () {
    expect(enlaceWhatsApp('+502 3282 8081', 'Ana').toString(),
        startsWith('https://wa.me/50232828081?'));
  });

  test('sin dígitos => null', () {
    expect(enlaceWhatsApp(' - ', 'Ana'), isNull);
  });
}
