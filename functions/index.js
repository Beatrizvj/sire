/**
 * Cloud Functions de SIRE.
 *
 * notificarNuevaAlerta: al crearse una alerta en `alertas/{id}`, envía una
 * notificación push (FCM) a las autoridades que deben atenderla:
 *   - Municipalidad: todas.
 *   - COCODE: solo el de la aldea de la alerta (ruteo por aldea).
 * Los tokens se leen de `usuarios/{uid}.fcmTokens` (los registra la app móvil
 * cuando AppConfig.pushEnabled está activo).
 *
 * Requiere plan Blaze. Desplegar con:  firebase deploy --only functions
 */
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

exports.notificarNuevaAlerta = onDocumentCreated(
    "alertas/{alertaId}",
    async (event) => {
      const alerta = event.data && event.data.data();
      if (!alerta) return;

      const aldea = alerta.aldea || "";
      const db = getFirestore();

      // Autoridades a notificar: municipalidad (todas) + cocode de la aldea.
      const snap = await db
          .collection("usuarios")
          .where("rol", "in", ["municipalidad", "cocode"])
          .get();

      const tokens = [];
      snap.forEach((doc) => {
        const u = doc.data();
        const esMuni = u.rol === "municipalidad";
        const esCocodeAldea = u.rol === "cocode" && (u.aldea || "") === aldea;
        if ((esMuni || esCocodeAldea) && Array.isArray(u.fcmTokens)) {
          tokens.push(...u.fcmTokens);
        }
      });

      const unicos = [...new Set(tokens)].filter(Boolean);
      if (unicos.length === 0) {
        console.log(`Sin tokens de autoridades para notificar (aldea="${aldea}").`);
        return;
      }

      const nombre = alerta.nombreUsuario || "Ciudadano";
      const categoria = alerta.categoria || "Sin especificar";
      const cuerpo = aldea ?
        `${nombre} · ${categoria} · ${aldea}` :
        `${nombre} · ${categoria}`;

      const resp = await getMessaging().sendEachForMulticast({
        tokens: unicos,
        notification: {title: "🚨 Nueva alerta SOS", body: cuerpo},
        data: {alertaId: event.params.alertaId, tipo: "sos"},
        android: {priority: "high"},
      });

      // Limpieza de tokens inválidos (dispositivos desinstalados/rotados).
      const invalidos = [];
      resp.responses.forEach((r, i) => {
        if (!r.success) {
          const code = (r.error && r.error.code) || "";
          if (
            code.includes("registration-token-not-registered") ||
            code.includes("invalid-argument")
          ) {
            invalidos.push(unicos[i]);
          }
        }
      });
      if (invalidos.length > 0) {
        const batch = db.batch();
        snap.forEach((doc) => {
          const u = doc.data();
          if (
            Array.isArray(u.fcmTokens) &&
            u.fcmTokens.some((t) => invalidos.includes(t))
          ) {
            batch.update(doc.ref, {
              fcmTokens: u.fcmTokens.filter((t) => !invalidos.includes(t)),
            });
          }
        });
        await batch.commit();
      }

      console.log(
          `Push enviado: ${resp.successCount}/${unicos.length} (aldea="${aldea}").`,
      );
    },
);

// Bot de WhatsApp (RF-12): avisa a las autoridades por WhatsApp (Twilio).
// Inerte hasta configurar las credenciales de Twilio en functions/.env.
exports.notificarWhatsAppNuevaAlerta =
    require("./whatsapp").notificarWhatsAppNuevaAlerta;
