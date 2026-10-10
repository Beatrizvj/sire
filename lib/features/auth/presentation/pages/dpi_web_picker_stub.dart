import 'dart:typed_data';

/// Implementación no-web (móvil/escritorio): no se usa, porque allí la captura
/// del DPI va por `image_picker` + recorte. Existe solo para el import
/// condicional de [elegirImagenWeb].
Future<Uint8List?> elegirImagenWeb() async => null;
