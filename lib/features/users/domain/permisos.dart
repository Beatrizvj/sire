import 'entities/app_user.dart';
import 'entities/user_role.dart';

/// Modelo de permisos por aldea (mismo criterio que `firestore.rules`):
///
/// - **Municipalidad:** administra todo el municipio.
/// - **Coordinador** (COCODE o Alcaldía Auxiliar con `esResponsable`): lo
///   designa SOLO la Municipalidad. Aprueba cuentas de su aldea, gestiona a sus
///   integrantes y puede delegar la aprobación a [maxDelegados] integrantes más.
/// - **Aprobador delegado** (`puedeVerIdentidad`): revisa el DPI y aprueba
///   ciudadanos de su aldea.
/// - **Demás integrantes:** atienden alertas; no aprueban ni editan cuentas.
const int maxDelegados = 2;

extension PermisosUsuario on AppUser {
  bool get esMunicipalidad => rol == UserRole.municipalidad;

  /// Coordinador del COCODE o de la Alcaldía Auxiliar de su aldea.
  bool get esCoordinador => rol.esAutoridadDeAldea && esResponsable;

  /// Aprobador delegado por el coordinador (o por la Municipalidad).
  bool get esDelegado =>
      rol.esAutoridadDeAldea && !esResponsable && puedeVerIdentidad;

  /// Puede revisar solicitudes de cuenta y aprobarlas o rechazarlas.
  bool get puedeAprobarCuentas => esMunicipalidad || esCoordinador || esDelegado;

  /// Puede ver las fotos del DPI de otros usuarios.
  bool get puedeVerDpi => puedeVerIdentidad || esCoordinador;

  /// Puede abrir "Editar" sobre [objetivo]. Nadie se edita a sí mismo desde la
  /// gestión de usuarios (su perfil se edita en "Mi perfil").
  bool puedeEditar(AppUser objetivo) {
    if (objetivo.id == id) return false;
    if (esMunicipalidad) return true;
    return esCoordinador &&
        objetivo.aldea == aldea &&
        !objetivo.esResponsable &&
        (objetivo.rol == UserRole.ciudadano || objetivo.rol == rol);
  }

  /// Roles que puede asignar al editar a un integrante de su aldea.
  List<UserRole> get rolesEditables => esMunicipalidad
      ? UserRole.values
      : esCoordinador
          ? [rol, UserRole.ciudadano]
          : const [];

  /// Nombre de la autoridad a la que este usuario debe acudir para corregir su
  /// nombre o su aldea (verificados con el DPI). [coordinadores] son los
  /// coordinadores de su aldea.
  String autoridadParaCorrecciones(List<AppUser> coordinadores) {
    if (rol != UserRole.ciudadano) return 'la Municipalidad';
    final aux = coordinadores.where((u) => u.rol == UserRole.auxiliatura);
    if (aux.isNotEmpty) return 'la Alcaldía Auxiliar de $aldea';
    final cocode = coordinadores.where((u) => u.rol == UserRole.cocode);
    if (cocode.isNotEmpty) return 'el COCODE de $aldea';
    return 'la Municipalidad';
  }
}

/// Integrantes de [aldea] y [rol] con aprobación delegada (sin el coordinador).
int delegadosEn(List<AppUser> todos, String aldea, UserRole rol) => todos
    .where((u) =>
        u.aldea == aldea && u.rol == rol && u.puedeVerIdentidad && !u.esResponsable)
    .length;
