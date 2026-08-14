/// Validación de nombres de usuario (R4).
///
/// Evita nombres extravagantes, ofensivos, falsos o poco serios. Se usa igual
/// en el registro y en "Editar mi perfil", tanto en la app móvil como en el
/// panel web (una sola fuente de reglas).
class NameValidator {
  NameValidator._();

  static const int minLongitud = 2;
  static const int maxLongitud = 60;

  /// Solo letras (con acentos y ñ), espacio, apóstrofo y guion. Cada "palabra"
  /// debe empezar y terminar en letra; se permiten nombres compuestos.
  static final RegExp _patron = RegExp(
    r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+([ '\-][A-Za-zÁÉÍÓÚÜÑáéíóúüñ]+)*$",
  );

  /// 3 o más letras iguales seguidas (p. ej. "aaaa", "jjj") → nombre no serio.
  static final RegExp _repetidas = RegExp(r'(.)\1\1', caseSensitive: false);

  /// Lista negra configurable de palabras ofensivas o burlescas (en minúsculas,
  /// sin acentos). Ampliable según la comunidad.
  static const List<String> listaNegra = [
    'puto', 'puta', 'mierda', 'idiota', 'estupido', 'imbecil', 'pendejo',
    'cabron', 'marica', 'perra', 'culero', 'verga', 'chinga', 'joto',
    'tonto', 'baboso', 'test', 'prueba', 'asdf', 'qwerty', 'nadie',
    'anonimo', 'fulano', 'mengano', 'xxx', 'ninguno',
  ];

  /// Devuelve un mensaje de error si el nombre no es válido, o null si lo es.
  /// [campo] permite personalizar el mensaje ("nombre", "apellido", …).
  static String? validar(String? valor, {String campo = 'nombre'}) {
    final s = (valor ?? '').trim();
    if (s.isEmpty) return 'Ingresa tu $campo.';
    if (s.length < minLongitud) return 'El $campo es muy corto.';
    if (s.length > maxLongitud) return 'El $campo es muy largo (máx. $maxLongitud).';
    if (!_patron.hasMatch(s)) {
      return 'El $campo solo puede tener letras, espacios, apóstrofo y guion '
          '(sin números ni símbolos).';
    }
    if (_repetidas.hasMatch(s)) {
      return 'Escribe tu $campo real (evita letras repetidas).';
    }
    final normalizado = _sinAcentos(s.toLowerCase());
    for (final palabra in normalizado.split(RegExp(r'[ \-]+'))) {
      if (listaNegra.contains(palabra)) {
        return 'Ese $campo no es válido. Usa tu nombre real.';
      }
    }
    return null;
  }

  /// Normaliza para guardar: recorta, colapsa espacios y capitaliza cada palabra
  /// ("juan  pérez " → "Juan Pérez").
  static String normalizar(String valor) {
    final limpio = valor.trim().replaceAll(RegExp(r'\s+'), ' ');
    return limpio
        .split(' ')
        .map((p) => p.isEmpty
            ? p
            : '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
        .join(' ');
  }

  static String _sinAcentos(String s) {
    const con = 'áéíóúüñ';
    const sin = 'aeiouun';
    var r = s;
    for (var i = 0; i < con.length; i++) {
      r = r.replaceAll(con[i], sin[i]);
    }
    return r;
  }
}
