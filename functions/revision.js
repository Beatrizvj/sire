/**
 * Cuentas de revisión de SIRE (p. ej. la del revisor de Google Play).
 */

/**
 * true si la alerta la generó una cuenta de revisión (`usuarios/{uid}`
 * con `cuentaRevision: true`, p. ej. la del revisor de Google Play). Esas
 * alertas no se notifican a nadie. La app ya no las envía; esto es una
 * segunda barrera por si llegara a escribirse alguna.
 * @param {FirebaseFirestore.Firestore} db
 * @param {object} alerta
 * @return {Promise<boolean>}
 */
async function esDeCuentaRevision(db, alerta) {
  const uid = alerta.idUsuario || "";
  if (!uid) return false;
  const u = await db.doc(`usuarios/${uid}`).get();
  return u.exists && u.get("cuentaRevision") === true;
}

module.exports = {esDeCuentaRevision};
