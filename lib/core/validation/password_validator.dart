/// Política de contraseñas de SIRE (módulo de seguridad).
///
/// Regla: **mínimo 8 caracteres, con al menos una letra y un número.** No se
/// exigen mayúsculas ni símbolos a propósito: se prioriza la longitud (en línea
/// con la guía NIST 800-63B) sin volver la contraseña tan compleja que la gente
/// del área rural la olvide o la anote en papel. Equilibrio seguridad/usabilidad.
class PasswordValidator {
  PasswordValidator._();

  static const int minLongitud = 8;

  /// Devuelve el mensaje de error, o `null` si la contraseña cumple la política.
  static String? validar(String? valor) {
    final v = valor ?? '';
    if (v.length < minLongitud) return 'Mínimo $minLongitud caracteres';
    final tieneLetra = RegExp(r'[A-Za-z]').hasMatch(v);
    final tieneNumero = RegExp(r'[0-9]').hasMatch(v);
    if (!tieneLetra || !tieneNumero) {
      return 'Usa al menos una letra y un número';
    }
    return null;
  }
}
