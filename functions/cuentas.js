/**
 * Ciclo de vida de las cuentas de SIRE (mejoras de la prueba con usuarios).
 *
 * 1. notificarCambioDeCuenta: cuando una autoridad APRUEBA o RECHAZA una
 *    solicitud, avisa al usuario con una notificación push (gratis) en su
 *    teléfono: "Tu cuenta fue aprobada por el COCODE de <aldea>".
 *    Al RECHAZAR, además borra el perfil y las fotos del DPI para que la
 *    persona pueda registrarse de nuevo con el mismo correo (el rechazo queda
 *    en la auditoría).
 *
 * 2. limpiarCuentaEliminada: cuando se borra un perfil de `usuarios/{uid}`
 *    (al eliminar un usuario desde el panel, o tras un rechazo), borra también
 *    su cuenta de acceso en Firebase Authentication y sus fotos del DPI. Solo
 *    el servidor puede borrar la cuenta de OTRA persona; por eso vive aquí y
 *    no en la app.
 */
const {onDocumentUpdated, onDocumentDeleted} =
  require("firebase-functions/v2/firestore");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const {getAuth} = require("firebase-admin/auth");
const logger = require("firebase-functions/logger");

/** Cómo se nombra a la autoridad que aprobó, según su rol. */
function nombreDeAutoridad(rol, aldea) {
  switch (rol) {
    case "cocode": return aldea ? `el COCODE de ${aldea}` : "el COCODE";
    case "auxiliatura":
      return aldea ? `la Alcaldía Auxiliar de ${aldea}` : "la Alcaldía Auxiliar";
    case "municipalidad": return "la Municipalidad";
    default: return "una autoridad";
  }
}

/** Envía un push a los dispositivos del usuario. No falla si no tiene. */
async function avisar(tokens, titulo, cuerpo) {
  const unicos = [...new Set(Array.isArray(tokens) ? tokens : [])];
  if (unicos.length === 0) return 0;
  const resp = await getMessaging().sendEachForMulticast({
    tokens: unicos,
    notification: {title: titulo, body: cuerpo},
    data: {tipo: "cuenta"},
    android: {priority: "high"},
  });
  return resp.successCount;
}

/** Borra las fotos del DPI de `identidad/{uid}/fotos`. */
async function borrarFotosDpi(db, uid) {
  const fotos = await db.collection(`identidad/${uid}/fotos`).listDocuments();
  await Promise.all(fotos.map((d) => d.delete()));
  return fotos.length;
}

exports.notificarCambioDeCuenta = onDocumentUpdated(
    "usuarios/{uid}",
    async (event) => {
      const antes = event.data.before.data() || {};
      const despues = event.data.after.data() || {};
      const estadoAntes = antes.estadoCuenta || "aprobado";
      const estadoDespues = despues.estadoCuenta || "aprobado";
      if (estadoAntes === estadoDespues) return;
      const uid = event.params.uid;
      const db = getFirestore();

      if (estadoDespues === "aprobado") {
        let quien = "una autoridad";
        if (despues.aprobadoPor) {
          const aut = await db.doc(`usuarios/${despues.aprobadoPor}`).get();
          if (aut.exists) {
            const a = aut.data();
            quien = nombreDeAutoridad(a.rol, a.aldea);
          }
        }
        const ok = await avisar(
            despues.fcmTokens,
            "✅ Tu cuenta de SIRE fue aprobada",
            `Tu registro fue aprobado por ${quien}. Ya puedes usar SIRE.`,
        );
        logger.info(`Cuenta aprobada ${uid}: aviso enviado a ${ok} dispositivo(s).`);
        return;
      }

      if (estadoDespues === "rechazado") {
        const ok = await avisar(
            despues.fcmTokens,
            "Tu solicitud en SIRE no fue aprobada",
            "Revisa tus datos y la foto de tu DPI y regístrate de nuevo.",
        );
        // Al borrar el perfil se dispara limpiarCuentaEliminada, que borra la
        // cuenta de acceso: así el correo queda libre para registrarse otra vez.
        await event.data.after.ref.delete();
        logger.info(`Cuenta rechazada ${uid}: aviso a ${ok} dispositivo(s); perfil borrado.`);
      }
    },
);

exports.limpiarCuentaEliminada = onDocumentDeleted(
    "usuarios/{uid}",
    async (event) => {
      const uid = event.params.uid;
      const fotos = await borrarFotosDpi(getFirestore(), uid);
      try {
        await getAuth().deleteUser(uid);
        logger.info(`Usuario ${uid}: cuenta de acceso y ${fotos} foto(s) del DPI borradas.`);
      } catch (e) {
        if (e && e.code === "auth/user-not-found") {
          logger.info(`Usuario ${uid}: sin cuenta de acceso; ${fotos} foto(s) borradas.`);
        } else {
          throw e;
        }
      }
    },
);
