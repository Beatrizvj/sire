/**
 * Bot de WhatsApp de SIRE (RF-12) — Meta WhatsApp Cloud API.
 *
 * Al crearse una alerta en `alertas/{id}`, envía un mensaje de WhatsApp (por
 * PLANTILLA aprobada) a las autoridades que deben atenderla.
 *
 * ENRUTAMIENTO (por rol y aldea):
 *   - Municipalidad: SIEMPRE recibe.
 *   - Alcaldía Auxiliar: si la aldea tiene números en `config/whatsapp_auxiliar`
 *     = { "<aldea>": ["+502..."] }, el WhatsApp va SOLO a esos números (no al
 *     COCODE). Caso La Emboscada. Son contactos de SOLO-RECEPCIÓN.
 *   - COCODE de la aldea: solo si la aldea NO tiene Alcaldía Auxiliar.
 * (El push —functions/index.js— no cambia: COCODE de la aldea + Municipalidad.)
 *
 * PROVEEDOR: Meta WhatsApp Cloud API (Graph API). Los mensajes iniciados por el
 * negocio EXIGEN una plantilla aprobada. Config por variables de entorno (en
 * `functions/.env`, que NO se sube a git; ver docs/WHATSAPP_SETUP.md):
 *   WHATSAPP_TOKEN            → token de acceso de Meta (permanente en producción)
 *   WHATSAPP_PHONE_NUMBER_ID  → ID del número remitente (NO el número: su ID)
 *   WHATSAPP_TEMPLATE         → nombre de la plantilla (def. "sire_alerta_sos")
 *   WHATSAPP_TEMPLATE_LANG    → idioma de la plantilla (def. "es")
 * Si faltan el token o el phone number ID, la función no hace nada (no-op).
 */
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {getFirestore} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");

const GRAPH_VERSION = "v21.0";

/** Normaliza a formato internacional; Guatemala (+502) si es local de 8 dígitos. */
function aFormatoInternacional(telefono) {
  const limpio = (telefono || "").replace(/[^0-9+]/g, "");
  if (!limpio) return "";
  if (limpio.startsWith("+")) return limpio;
  const digitos = limpio.replace(/\D/g, "");
  if (digitos.length === 8) return `+502${digitos}`;
  return `+${digitos}`;
}

/** Enlace a la ubicación en el mapa (§3.7). Vacío si no hay coordenadas útiles. */
function enlaceMapa(lat, lng) {
  const okLat = typeof lat === "number" && isFinite(lat);
  const okLng = typeof lng === "number" && isFinite(lng);
  if (!okLat || !okLng || (lat === 0 && lng === 0)) return "";
  return `https://www.google.com/maps?q=${lat},${lng}`;
}

/** Envía UNA plantilla a un número por la Cloud API de Meta. */
async function enviarPlantillaMeta({token, phoneNumberId, plantilla, idioma, to, params}) {
  const url = `https://graph.facebook.com/${GRAPH_VERSION}/${phoneNumberId}/messages`;
  const cuerpo = {
    messaging_product: "whatsapp",
    to: to.replace(/^\+/, ""), // Meta espera el número sin el '+'
    type: "template",
    template: {
      name: plantilla,
      language: {code: idioma},
      components: [
        {
          type: "body",
          parameters: params.map((texto) => ({type: "text", text: texto})),
        },
      ],
    },
  };
  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(cuerpo),
  });
  if (!resp.ok) {
    const detalle = await resp.text();
    throw new Error(`HTTP ${resp.status} ${detalle}`);
  }
  return resp.json();
}

exports.notificarWhatsAppNuevaAlerta = onDocumentCreated(
    "alertas/{alertaId}",
    async (event) => {
      const token = process.env.WHATSAPP_TOKEN;
      const phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID;
      const plantilla = process.env.WHATSAPP_TEMPLATE || "sire_alerta_sos";
      const idioma = process.env.WHATSAPP_TEMPLATE_LANG || "es";
      if (!token || !phoneNumberId) {
        logger.info("WhatsApp desactivado: faltan credenciales de Meta.");
        return;
      }

      const alerta = event.data && event.data.data();
      if (!alerta) return;

      const aldea = alerta.aldea || "";
      const db = getFirestore();

      // ¿La aldea tiene Alcaldía Auxiliar con números para WhatsApp?
      // config/whatsapp_auxiliar = { "La Emboscada": ["+502########", ...] }.
      let numerosAuxiliar = [];
      try {
        const cfg = await db.doc("config/whatsapp_auxiliar").get();
        const mapa = (cfg.exists && cfg.data()) || {};
        if (Array.isArray(mapa[aldea])) numerosAuxiliar = mapa[aldea];
      } catch (e) {
        logger.warn(`No se pudo leer config/whatsapp_auxiliar: ${e && e.message}`);
      }
      const tieneAuxiliar = numerosAuxiliar.length > 0;

      const telefonos = [];

      // Municipalidad (siempre) + COCODE de la aldea (solo si NO hay Auxiliatura).
      const snap = await db
          .collection("usuarios")
          .where("rol", "in", ["municipalidad", "cocode"])
          .get();
      snap.forEach((doc) => {
        const u = doc.data();
        const esMuni = u.rol === "municipalidad";
        const esCocodeAldea =
          u.rol === "cocode" && (u.aldea || "") === aldea && !tieneAuxiliar;
        if (esMuni || esCocodeAldea) {
          const tel = aFormatoInternacional(u.telefono);
          if (tel) telefonos.push(tel);
        }
      });

      // Alcaldía Auxiliar (solo-recepción): recibe EN LUGAR del COCODE.
      if (tieneAuxiliar) {
        numerosAuxiliar.forEach((n) => {
          const tel = aFormatoInternacional(n);
          if (tel) telefonos.push(tel);
        });
      }

      const unicos = [...new Set(telefonos)];
      if (unicos.length === 0) {
        logger.info(`Sin destinatarios de WhatsApp (aldea="${aldea}").`);
        return;
      }

      // Variables de la plantilla: {{1}} nombre · {{2}} categoría · {{3}}
      // comunidad · {{4}} ubicación (enlace de mapa, o dirección, o texto por
      // defecto; Meta exige que ninguna variable vaya vacía).
      const nombre = alerta.nombreUsuario || "Ciudadano";
      const categoria = alerta.categoria || "Sin especificar";
      const comunidad = aldea || "Sin especificar";
      const ubicacion =
        enlaceMapa(alerta.latitud, alerta.longitud) ||
        alerta.address ||
        "Ubicacion no disponible";
      const params = [nombre, categoria, comunidad, ubicacion];

      const resultados = await Promise.allSettled(
          unicos.map((tel) =>
            enviarPlantillaMeta({
              token,
              phoneNumberId,
              plantilla,
              idioma,
              to: tel,
              params,
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
      logger.info(
          `WhatsApp (Meta) enviado: ${ok}/${unicos.length} ` +
          `(aldea="${aldea}", auxiliar=${tieneAuxiliar}).`,
      );
    },
);
