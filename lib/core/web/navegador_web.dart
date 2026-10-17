import 'package:web/web.dart' as web;

/// Recarga la página para cargar la versión nueva del panel.
void recargarPagina() => web.window.location.reload();

/// Abre [url] en una pestaña nueva. Debe llamarse DIRECTO en el clic (sin
/// await antes): así el navegador no lo bloquea como ventana emergente.
void abrirEnPestanaNueva(String url) {
  web.window.open(url, '_blank', 'noopener');
}
