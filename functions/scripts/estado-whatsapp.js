/**
 * Diagnóstico del WhatsApp de SIRE (Twilio). Solo LEE; no envía nada.
 * Uso (desde functions/):  node scripts/estado-whatsapp.js
 *
 * Muestra el estado de los remitentes y, por destinatario, la última entrega:
 *   63015 = el teléfono no se ha unido al sandbox ("join <código>")
 *   63016 = pasaron más de 24 h desde el último mensaje de ese teléfono al
 *           sandbox (fuera de la ventana; solo con plantilla aprobada)
 */
const fs = require("fs");
const path = require("path");

const env = Object.fromEntries(
    fs.readFileSync(path.join(__dirname, "..", ".env"), "utf8")
        .split(/\r?\n/)
        .filter((l) => /^TWILIO_[A-Z_]+=/.test(l))
        .map((l) => [l.split("=")[0], l.slice(l.indexOf("=") + 1).trim()]),
);
const sid = env.TWILIO_ACCOUNT_SID;
const auth = "Basic " + Buffer.from(`${sid}:${env.TWILIO_AUTH_TOKEN}`).toString("base64");
const get = async (url) => (await fetch(url, {headers: {Authorization: auth}})).json();

const EXPLICACION = {
  63015: "no unido al sandbox: enviar 'join <código>'",
  63016: "ventana de 24 h vencida: volver a enviar 'join <código>'",
};

(async () => {
  const remitentes = await get(
      "https://messaging.twilio.com/v2/Channels/Senders?Channel=whatsapp&PageSize=20");
  console.log("== Remitentes ==");
  for (const s of remitentes.senders || []) {
    const motivo = (s.offline_reasons || []).map((r) => r.code).join(",");
    console.log(`  ${s.sender_id.padEnd(24)} ${s.status}${motivo ? " (" + motivo + ")" : ""}`);
  }

  const msgs = (await get(
      `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json?PageSize=100`)).messages || [];
  const ultimo = new Map();
  const ultimoJoin = new Map();
  for (const m of msgs) {
    if (m.direction === "inbound") {
      if (!ultimoJoin.has(m.from)) ultimoJoin.set(m.from, m.date_created);
    } else if (!ultimo.has(m.to)) {
      ultimo.set(m.to, m);
    }
  }
  console.log("\n== Último envío por destinatario ==");
  for (const [to, m] of ultimo) {
    const err = m.error_code ? ` ${m.error_code} → ${EXPLICACION[m.error_code] || "ver twilio.com/docs/errors"}` : "";
    console.log(`  ${to.padEnd(24)} ${m.status.padEnd(12)}${err}`);
  }
  console.log("\n== Último mensaje recibido de cada teléfono (join) ==");
  const ahora = Date.now();
  for (const [from, fecha] of ultimoJoin) {
    const horas = (ahora - new Date(fecha).getTime()) / 36e5;
    const ok = horas < 24 ? "✅ dentro de 24 h" : "⚠️  vencido: reenviar join";
    console.log(`  ${from.padEnd(24)} hace ${horas.toFixed(1)} h  ${ok}`);
  }
})();
