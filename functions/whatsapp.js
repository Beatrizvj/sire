/**
 * Bot de WhatsApp de SIRE (RF-12).
 *
 * notificarWhatsAppNuevaAlerta: al crearse una alerta en `alertas/{id}`, envía
 * un mensaje de WhatsApp a las autoridades que deben atenderla (Municipalidad +
 * COCODE de la aldea), usando el teléfono de su perfil (`usuarios/{uid}.telefono`).
 * Reutiliza el mismo ruteo por rol y aldea que el push (`notificarNuevaAlerta`).
 *
 * Proveedor: Twilio (WhatsApp). Credenciales en `functions/.env` (NO se sube a
 * git). Ver docs/WHATSAPP_SETUP.md.
 *   TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_WHATSAPP_FROM
 * Si faltan, la función no hace nada (no-op): se puede desplegar sin romper.
 *
 * NOTA (demo): usamos `.env` por simplicidad. Para PRODUCCIÓN (octubre) conviene
 * migrar a Secret Manager (`firebase functions:secrets:set ...`).
 */
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {getFirestore} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");

/** Normaliza a formato internacional; Guatemala (+502) si es local de 8 dígitos. */
function aFormatoInternacional(telefono) {
  const limpio = (telefono || "").replace(/[^0-9+]/g, "");
  if (!limpio) return "";
  if (limpio.startsWith("+")) return limpio;
  const digitos = limpio.replace(/\D/g, "");
  if (digitos.length === 8) return `+502${digitos}`;
  return `+${digitos}`;
}

exports.notificarWhatsAppNuevaAlerta = onDocumentCreated(
    "alertas/{alertaId}",
    async (event) => {
      const sid = process.env.TWILIO_ACCOUNT_SID;
      const token = process.env.TWILIO_AUTH_TOKEN;
      const from = process.env.TWILIO_WHATSAPP_FROM;
      if (!sid || !token || !from) {
        logger.info("WhatsApp desactivado: faltan credenciales de Twilio.");
        return;
      }

      const alerta = event.data && event.data.data();
      if (!alerta) return;

      const aldea = alerta.aldea || "";
      const db = getFirestore();

      // Mismas autoridades que el push: municipalidad (todas) + cocode de la aldea.
      const snap = await db
          .collection("usuarios")
          .where("rol", "in", ["municipalidad", "cocode"])
          .get();

      const telefonos = [];
      snap.forEach((doc) => {
        const u = doc.data();
        const esMuni = u.rol === "municipalidad";
        const esCocodeAldea = u.rol === "cocode" && (u.aldea || "") === aldea;
        if (esMuni || esCocodeAldea) {
          const tel = aFormatoInternacional(u.telefono);
          if (tel) telefonos.push(tel);
        }
      });

      const unicos = [...new Set(telefonos)];
      if (unicos.length === 0) {
        logger.info(`Sin teléfonos de autoridades para WhatsApp (aldea="${aldea}").`);
        return;
      }

      const nombre = alerta.nombreUsuario || "Ciudadano";
      const categoria = alerta.categoria || "Sin especificar";
      const detalle = aldea ?
        `${nombre} · ${categoria} · ${aldea}` :
        `${nombre} · ${categoria}`;
      const cuerpo = `🚨 *Nueva alerta SOS - SIRE*\n${detalle}`;

      const twilioClient = require("twilio")(sid, token);

      const resultados = await Promise.allSettled(
          unicos.map((tel) =>
            twilioClient.messages.create({
              from: from,
              to: `whatsapp:${tel}`,
              body: cuerpo,
            }),
          ),
      );

      let ok = 0;
      resultados.forEach((r, i) => {
        if (r.status === "fulfilled") {
          ok += 1;
        } else {
          logger.warn(
              `WhatsApp falló a ${unicos[i]}: ${r.reason && r.reason.message}`,
          );
        }
      });
      logger.info(`WhatsApp enviado: ${ok}/${unicos.length} (aldea="${aldea}").`);
    },
);
