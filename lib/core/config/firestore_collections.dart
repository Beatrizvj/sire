/// Nombres de las colecciones de Cloud Firestore (esquema de la tesis SIRE).
class FirestoreCollections {
  FirestoreCollections._();

  static const String usuarios = 'usuarios';
  static const String alertas = 'alertas';
  // R1: bitácora inmutable de acciones sensibles (aprobaciones, roles, accesos).
  static const String auditoria = 'auditoria';
  // R3: catálogo configurable de categorías de incidente.
  static const String categoriasIncidente = 'categorias_incidente';
  // R2: fotos del DPI (anverso/reverso) para verificación de identidad.
  static const String identidad = 'identidad';
  // Catálogo de aldeas/comunidades del municipio, administrable desde el panel
  // (las 4 base más las que agregue la Municipalidad).
  static const String aldeas = 'aldeas';
  // Reservada para hitos posteriores:
  static const String comunidades = 'comunidades';
}
