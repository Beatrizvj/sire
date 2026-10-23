/// Número de compilación de ESTE código (el `+N` de `pubspec.yaml`).
///
/// El panel web lo compara con `/version.json` del servidor para avisar que se
/// publicó una versión nueva. Debe coincidir con `pubspec.yaml` (lo verifica
/// `test/unit/version_app_test.dart`).
const int kNumeroCompilacion = 18;

/// Versión visible (el `x.y.z` de `pubspec.yaml`).
const String kVersionNombre = '1.0.0';

/// Versión completa (`x.y.z+N`) que se guarda en cada alerta (`versionApp`)
/// para saber desde qué versión de la app se envió.
const String kVersionCompleta = '$kVersionNombre+$kNumeroCompilacion';
