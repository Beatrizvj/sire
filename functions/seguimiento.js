/**
 * Seguimiento en vivo por enlace (ubicación en vivo, parte 2).
 *
 * El WhatsApp de una alerta lleva un enlace privado
 * `https://siresanmiguel.com/seguir.html?t=<token>`. El token es aleatorio
 * (128 bits) y se guarda en `seguimiento/{token}` = {alertaId, creadoEn}; esa
 * colección NO es legible por los clientes (catch-all de las reglas), solo por
 * esta función. Así lo pueden abrir también los contactos de solo-recepción,
 * que no tienen cuenta.
 *
 * `ubicacionEnVivo` (HTTPS, servida en /api/seguimiento por el hosting)
 * devuelve la última posición mientras la alerta siga abierta, el ciudadano no
 * haya tocado "Dejar de compartir" y no hayan pasado 2 h (igual que
 * LiveTrackingService.kt y las reglas). Si no, ya no entrega coordenadas.
 */
const crypto = require("crypto");
const {onRequest} = require("firebase-functions/v2/https");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");

const DURACION_MAX_MS = 2 * 60 * 60 * 1000;
const CERRADAS = ["resuelta", "falsa_alarma"];

/** Crea el token de seguimiento de [alertaId] y lo devuelve. */
async function crearTokenSeguimiento(db, alertaId) {
  const token = crypto.randomBytes(16).toString("hex");
  await db.doc(`seguimiento/${token}`).set({
    alertaId,
    creadoEn: FieldValue.serverTimestamp(),
  });
  return token;
}

const aFecha = (v) => (v && typeof v.toDate === "function" ? v.toDate() : null);

exports.crearTokenSeguimiento = crearTokenSeguimiento;

exports.ubicacionEnVivo = onRequest({invoker: "public"}, async (req, res) => {
  res.set("Cache-Control", "no-store");
  const token = String(req.query.t || "");
  if (!/^[0-9a-f]{32}$/.test(token)) {
    res.status(400).json({error: "Enlace no válido."});
    return;
  }
  try {
    const db = getFirestore();
    const seg = await db.doc(`seguimiento/${token}`).get();
    if (!seg.exists) {
      res.status(404).json({error: "Enlace no válido o vencido."});
      return;
    }
    const alertaSnap = await db.doc(`alertas/${seg.data().alertaId}`).get();
    if (!alertaSnap.exists) {
      res.status(404).json({error: "La alerta ya no existe."});
      return;
    }
    const a = alertaSnap.data();
    const fecha = aFecha(a.fecha);
    const estado = a.estado || "pendiente";
    const vencida = fecha && Date.now() - fecha.getTime() > DURACION_MAX_MS;
    const detenido = a.seguimientoDetenidoEn != null;
    const activo = !CERRADAS.includes(estado) && !vencida && !detenido;

    const cuerpo = {
      nombre: a.nombreUsuario || "Ciudadano",
      categoria: a.categoria || "Sin especificar",
      aldea: a.aldea || "",
      estado,
      fecha: fecha ? fecha.toISOString() : null,
      activo,
      // Por qué terminó: "detenido" (lo cortó el ciudadano), "cerrada" o "vencida".
      motivo: activo ? null :
        detenido ? "detenido" : CERRADAS.includes(estado) ? "cerrada" : "vencida",
    };
    if (activo) {
      const lat = a.latitudActual != null ? a.latitudActual : a.latitud;
      const lng = a.longitudActual != null ? a.longitudActual : a.longitud;
      if (lat != null && lng != null && !(lat === 0 && lng === 0)) {
        const actualizado = aFecha(a.ubicacionActualEn);
        // "En vivo" solo si el último punto tiene < 2 min (igual que el panel).
        const enVivo = a.latitudActual != null && actualizado != null &&
          Date.now() - actualizado.getTime() < 2 * 60 * 1000;
        cuerpo.ubicacion = {
          lat,
          lng,
          precision: enVivo ? a.precisionActual || null : a.precision || null,
          enVivo,
          actualizadoEn: actualizado ?
            actualizado.toISOString() :
            cuerpo.fecha,
        };
      }
    }
    res.json(cuerpo);
  } catch (e) {
    logger.error(`ubicacionEnVivo: ${e && e.message}`);
    res.status(500).json({error: "No se pudo consultar la alerta."});
  }
});
