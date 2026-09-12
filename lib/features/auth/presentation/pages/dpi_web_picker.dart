import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Abre el explorador de archivos con un `<input type="file">` REAL del DOM y
/// devuelve los bytes de la imagen elegida (o `null` si se cancela).
///
/// Se usa SOLO en web: allí `image_picker` dispara el selector con un click
/// "sintético" desde el lienzo de Flutter (CanvasKit) que el navegador bloquea,
/// por lo que no se abría nada. Un `<input>` real del DOM, con `.click()`
/// llamado dentro del gesto del usuario, sí abre el explorador.
Future<Uint8List?> elegirImagenWeb() {
  final completer = Completer<Uint8List?>();

  final input = web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.accept = 'image/*';

  input.addEventListener(
    'change',
    (web.Event _) {
      final files = input.files;
      if (files == null || files.length == 0) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      final reader = web.FileReader();
      reader.addEventListener(
        'loadend',
        (web.Event _) {
          final result = reader.result;
          if (result == null) {
            if (!completer.isCompleted) completer.complete(null);
            return;
          }
          final bytes = (result as JSArrayBuffer).toDart.asUint8List();
          if (!completer.isCompleted) completer.complete(bytes);
        }.toJS,
      );
      reader.readAsArrayBuffer(files.item(0)!);
    }.toJS,
  );

  // Click SÍNCRONO dentro del gesto del toque → el navegador permite abrirlo.
  input.click();
  return completer.future;
}
