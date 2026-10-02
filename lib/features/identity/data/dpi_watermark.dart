import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Marca de agua para las fotos del DPI (recomendación post-Beta del asesor).
///
/// Se hornea en el CLIENTE, antes de subir la imagen a Firestore, de modo que
/// el servidor nunca almacene una copia limpia del documento. Así, ni la
/// Municipalidad (administrador) ni el COCODE pueden reutilizar la foto del DPI
/// del ciudadano para otro fin: cualquier copia que obtengan lleva impreso su
/// origen ("SIRE - verificacion de identidad") y la fecha de captura.
///
/// Para que se vea sobre CUALQUIER fondo (claro, oscuro o colorido) sin tapar el
/// documento, cada texto se dibuja dos veces: una sombra oscura desplazada y,
/// encima, el texto claro. El patrón es diagonal, repetido y semitransparente.
Uint8List marcarDpiConAguaSire(Uint8List original, {DateTime? fecha}) {
  final base = img.decodeImage(original);
  if (base == null) return original; // formato no reconocido: se sube tal cual

  final f = fecha ?? DateTime.now();
  // Sin acentos ni signos especiales: la fuente bitmap del paquete `image` solo
  // trae glifos ASCII (una "ó" saldría como hueco).
  final texto = 'SIRE - verificacion de identidad - '
      '${f.year}-${_dd(f.month)}-${_dd(f.day)}';

  final font = img.arial24;
  // Sombra oscura + texto claro: contraste sobre cualquier fondo.
  final sombra = img.ColorRgba8(0, 0, 0, 115);
  final tinta = img.ColorRgba8(255, 255, 255, 150);

  // Capa cuadrada mayor que la diagonal de la foto: al rotarla, sigue cubriendo
  // toda la imagen (sin dejar esquinas sin marcar).
  final diagonal =
      math.sqrt(base.width * base.width + base.height * base.height);
  final lado = (diagonal * 1.3).ceil();
  final capa = img.Image(width: lado, height: lado, numChannels: 4);

  // Repite el texto en mosaico. Ancho estimado del texto (arial24 ≈ 13 px/car.).
  final anchoTexto = texto.length * 13 + 48;
  const altoFila = 84;
  for (var y = 0; y < lado; y += altoFila) {
    // Las filas alternas arrancan medio mosaico a la derecha (patrón ladrillo).
    final inicio = (y ~/ altoFila).isEven ? 0 : anchoTexto ~/ 2;
    for (var x = inicio; x < lado; x += anchoTexto) {
      img.drawString(capa, texto, font: font, x: x + 2, y: y + 2, color: sombra);
      img.drawString(capa, texto, font: font, x: x, y: y, color: tinta);
    }
  }

  // Inclina la capa (-30°) y la compone centrada sobre la foto original.
  final rotada = img.copyRotate(capa, angle: -30);
  img.compositeImage(base, rotada, center: true);

  return img.encodeJpg(base, quality: 70);
}

String _dd(int n) => n.toString().padLeft(2, '0');
