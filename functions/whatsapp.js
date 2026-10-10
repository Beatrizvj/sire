/**
 * Bot de WhatsApp de SIRE (RF-12) — Twilio o Meta WhatsApp Cloud API.
 *
 * Al crearse una alerta en `alertas/{id}`, envía un mensaje de WhatsApp a las
 * autoridades que deben atenderla.
 *
 * ENRUTAMIENTO (por rol y aldea):
 *   - Municipalidad: SIEMPRE recibe.
 *   - Alcaldía Auxiliar de la aldea: solo sus RESPONSABLES (rol `auxiliatura`
 *     con `esResponsable`, los marca la Municipalidad) y los contactos de
 *     SOLO-RECEPCIÓN de `config/whatsapp_auxiliar` = { "<aldea>": ["+502..."] }.
 *     Los demás integrantes reciben solo el push (gratis). Caso La Emboscada.
 *   - COCODE de la aldea: solo si la aldea NO tiene Alcaldía Auxiliar (ni por
 *     rol ni por config); si la tiene, el WhatsApp va a la Auxiliatura.
 * (El push —functions/index.js— va a la Municipalidad y a TODAS las autoridades
 * de la aldea: COCODE y Alcaldía Auxiliar.)
 *
 * PROVEEDOR: se elige con WHATSAPP_PROVIDER ("twilio" | "meta"). Si no se
 * indica, se usa Twilio cuando están sus credenciales y, si no, Meta. Config por
 * variables de entorno (en `functions/.env`, que NO se sube a git; ver
 * docs/WHATSAPP_SETUP.md):
 *   Twilio:
 *     TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN
 *     TWILIO_WHATSAPP_FROM      → "whatsapp:+14155238886" (sandbox) o el propio
 *     TWILIO_CONTENT_SID        → (opcional, producción) plantilla aprobada
 *                                 "HX…"; sin ella se envía texto libre, que es
 *                                 lo que admite el sandbox.
 *   Meta (las plantillas son obligatorias):
 *     WHATSAPP_TOKEN            → token de acceso (permanente en producción)
 *     WHATSAPP_PHONE_NUMBER_ID  → ID del número remitente (NO el número: su ID)
 *     WHATSAPP_TEMPLATE         → nombre de la plantilla (def. "sire_alerta_sos")
 *     WHATSAPP_TEMPLATE_LANG    → idioma de la plantilla (def. "es")
 * Si faltan las credenciales del proveedor, la función no hace nada (no-op).
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

/**
 * Arma el emisor según el proveedor configurado. Devuelve
 * { nombre, enviar(to, params) } o null si faltan credenciales.
 * params = [nombre, categoría, comunidad, ubicación].
 */
function crearEmisor() {
  const env = process.env;
  const hayTwilio =
    env.TWILIO_ACCOUNT_SID && env.TWILIO_AUTH_TOKEN && env.TWILIO_WHATSAPP_FROM;
  const proveedor =
    (env.WHATSAPP_PROVIDER || (hayTwilio ? "twilio" : "meta")).toLowerCase();

  if (proveedor === "twilio") {
    if (!hayTwilio) return null;
    const cliente = require("twilio")(env.TWILIO_ACCOUNT_SID, env.TWILIO_AUTH_TOKEN);
    const contentSid = env.TWILIO_CONTENT_SID;
    return {
      nombre: "Twilio",
      enviar: (to, params) => {
        const base = {from: env.TWILIO_WHATSAPP_FROM, to: `whatsapp:${to}`};
        if (contentSid) {
          // Plantilla aprobada: mismas variables {{1}}..{{4}} que en Meta.
          const variables = {};
          params.forEach((v, i) => (variables[String(i + 1)] = v));
          return cliente.messages.create({
            ...base,
            contentSid,
            contentVariables: JSON.stringify(variables),
          });
        }
        const [nombre, categoria, comunidad, ubicacion] = params;
        return cliente.messages.create({
          ...base,
          body:
            "🚨 *Nueva alerta SOS - SIRE*\n" +
            `Ciudadano: ${nombre}\n` +
            `Categoría: ${categoria}\n` +
            `Comunidad: ${comunidad}\n` +
            `Ubicación: ${ubicacion}`,
        });
      },
    };
  }

  if (!env.WHATSAPP_TOKEN || !env.WHATSAPP_PHONE_NUMBER_ID) return null;
  return {
    nombre: "Meta",
    enviar: (to, params) =>
      enviarPlantillaMeta({
        token: env.WHATSAPP_TOKEN,
        phoneNumberId: env.WHATSAPP_PHONE_NUMBER_ID,
        plantilla: env.WHATSAPP_TEMPLATE || "sire_alerta_sos",
        idioma: env.WHATSAPP_TEMPLATE_LANG || "es",
        to,
        params,
      }),
  };
}

exports.notificarWhatsAppNuevaAlerta = onDocumentCreated(
    "alertas/{alertaId}",
    async (event) => {
      const emisor = crearEmisor();
      if (!emisor) {
        logger.info("WhatsApp desactivado: faltan credenciales del proveedor.");
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
      const snap = await db
          .collection("usuarios")
          .where("rol", "in", ["municipalidad", "cocode", "auxiliatura"])
          .get();
      const autoridades = snap.docs.map((doc) => doc.data());
      const deLaAldea = (u) => (u.aldea || "") === aldea;
      const esResponsableAux = (u) =>
        u.rol === "auxiliatura" && u.esResponsable === true && deLaAldea(u);
      const auxiliaturaPorRol = autoridades.filter(esResponsableAux);
      const tieneAuxiliar =
        numerosAuxiliar.length > 0 || auxiliaturaPorRol.length > 0;

      const telefonos = [];

      // Municipalidad (siempre) + responsables de la Alcaldía Auxiliar de la
      // aldea + COCODE de la aldea (solo si NO hay Auxiliatura).
      autoridades.forEach((u) => {
        const esMuni = u.rol === "municipalidad";
        const esAuxAldea = esResponsableAux(u);
        const esCocodeAldea =
          u.rol === "cocode" && deLaAldea(u) && !tieneAuxiliar;
        if (esMuni || esAuxAldea || esCocodeAldea) {
          const tel = aFormatoInternacional(u.telefono);
          if (tel) telefonos.push(tel);
        }
      });

      // Contactos de solo-recepción de la Alcaldía Auxiliar (sin cuenta).
      if (numerosAuxiliar.length > 0) {
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
          unicos.map((tel) => emisor.enviar(tel, params)),
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
          `WhatsApp (${emisor.nombre}) enviado: ${ok}/${unicos.length} ` +
          `(aldea="${aldea}", auxiliar=${tieneAuxiliar}).`,
      );
    },
);
