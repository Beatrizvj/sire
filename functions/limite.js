/**
 * Límite de WhatsApp por ciudadano (control de abuso y de costo).
 *
 * Cada WhatsApp cuesta dinero (Twilio + Meta), así que un mismo ciudadano solo
 * dispara una ronda de WhatsApp:
 *   - una vez cada LIMITE_WA_MINUTOS (def. 10) minutos, y
 *   - como máximo LIMITE_WA_POR_DIA (def. 3) veces por día (hora de Guatemala).
 * Las alertas que pasen el límite se guardan igual, salen en el panel y llegan
 * por push (gratis); solo se omite el WhatsApp.
 *
 * El estado vive en `limites_whatsapp/{uid}` = { ultimoEnvio, dia, enviosDia }.
 * Las reglas de Firestore no abren esa colección: solo la toca el servidor.
 */

const MINUTO = 60 * 1000;
const DIA = 24 * 60 * MINUTO;
// Guatemala es UTC-6 todo el año (sin horario de verano).
const DESFASE_GT = 6 * 60 * MINUTO;

function opcionesPorDefecto() {
  const env = process.env;
  return {
    minutos: Number(env.LIMITE_WA_MINUTOS) || 10,
    porDia: Number(env.LIMITE_WA_POR_DIA) || 3,
  };
}

/** Número de día (en hora de Guatemala) de un instante en ms. */
function diaGuatemala(ms) {
  return Math.floor((ms - DESFASE_GT) / DIA);
}

/**
 * Decide si se permite el WhatsApp. Función pura (se prueba sin Firestore).
 * @param {{ultimoEnvio?: number, dia?: number, enviosDia?: number}|null} estado
 * @param {number} ahora ms
 * @param {{minutos: number, porDia: number}} opciones
 * @return {{permitir: boolean, motivo: string, nuevoEstado: object|null}}
 */
function decidir(estado, ahora, opciones) {
  const e = estado || {};
  const hoy = diaGuatemala(ahora);
  const enviosHoy = e.dia === hoy ? e.enviosDia || 0 : 0;

  if (typeof e.ultimoEnvio === "number" &&
      ahora - e.ultimoEnvio < opciones.minutos * MINUTO) {
    return {permitir: false, motivo: `menos de ${opciones.minutos} min`, nuevoEstado: null};
  }
  if (enviosHoy >= opciones.porDia) {
    return {permitir: false, motivo: `ya ${enviosHoy} hoy`, nuevoEstado: null};
  }
  return {
    permitir: true,
    motivo: "ok",
    nuevoEstado: {ultimoEnvio: ahora, dia: hoy, enviosDia: enviosHoy + 1},
  };
}

/**
 * Consulta y reserva el cupo en una transacción (dos alertas simultáneas del
 * mismo ciudadano no pasan las dos). Sin uid no se limita.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} uid
 * @param {number} [ahora]
 * @return {Promise<{permitir: boolean, motivo: string}>}
 */
async function reservarCupoWhatsApp(db, uid, ahora = Date.now()) {
  if (!uid) return {permitir: true, motivo: "sin uid"};
  const ref = db.doc(`limites_whatsapp/${uid}`);
  const opciones = opcionesPorDefecto();
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const r = decidir(snap.exists ? snap.data() : null, ahora, opciones);
    if (r.permitir) tx.set(ref, r.nuevoEstado);
    return {permitir: r.permitir, motivo: r.motivo};
  });
}

module.exports = {decidir, diaGuatemala, reservarCupoWhatsApp};
