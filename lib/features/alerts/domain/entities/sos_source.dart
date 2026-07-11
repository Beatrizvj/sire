/// Origen desde el cual se disparó una alerta SOS.
enum SosSource {
  /// Botón SOS en pantalla.
  screenButton,

  /// 3 pulsaciones del botón de encendido (núcleo de SIRE).
  powerButton;

  String get label => switch (this) {
        SosSource.screenButton => 'Botón en pantalla',
        SosSource.powerButton => 'Botón de encendido (×3)',
      };
}
