/**
 * Bitácora de acciones de SIRE (control y auditoría).
 *
 * Registra en `auditoria` quién hizo qué, cuándo y sobre qué, para la
 * Municipalidad, el COCODE y la Alcaldía Auxiliar:
 *
 * 1. registrarCambioDeAlerta: atender, resolver, falsa alarma, reabrir y
 *    clasificar una alerta.
 * 2. registrarCambioDeUsuario: aprobar, suspender o reactivar una cuenta,
 *    cambiar rol, designar coordinador, delegar la aprobación, armar los
 *    contactos de confianza y corregir nombre o aldea.
 *
 * El actor sale del campo `modificadoPor`, que la app escribe junto con
 * `modificadoEn` (hora del servidor) y que las reglas exigen que sea el usuario
 * autenticado. Como lo escribe el servidor, nadie puede alterar ni borrar la
 * bitácora (las reglas prohíben editarla o borrarla).
 *
 * El rechazo de una cuenta lo registra la app (lleva el motivo) y la vista del
 * DPI también: no son cambios que el servidor pueda ver.
 */
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");

/** Quién hizo el cambio: solo si esta escritura trae su propia marca. */
async function actorDe(db, antes, despues) {
  const uid = despues.modificadoPor || "";
  const marcaNueva = despues.modificadoEn &&
    (!antes.modificadoEn || !despues.modificadoEn.isEqual(antes.modificadoEn));
  if (!uid || !marcaNueva) {
    // Escritura de una versión anterior de la app (sin marca de actor).
    return {uid: "", nombre: "Desconocido (versión anterior de la app)",
      rol: "", aldea: ""};
  }
  const doc = await db.doc(`usuarios/${uid}`).get();
  const u = doc.exists ? doc.data() : {};
  return {
    uid,
    nombre: u.nombre || "",
    rol: u.rol || "",
    aldea: u.aldea || "",
    esResponsable: u.esResponsable === true,
  };
}

/** Escribe un registro en la bitácora. */
async function registrar(db, actor, datos) {
  await db.collection("auditoria").add({
    actorUid: actor.uid,
    actorNombre: actor.nombre,
    actorRol: actor.rol,
    actorCoordinador: actor.esResponsable === true,
    valorAnterior: null,
    valorNuevo: null,
    detalle: null,
    ...datos,
    origen: "servidor",
    fechaHora: FieldValue.serverTimestamp(),
  });
}

const ACCION_POR_ESTADO = {
  atendida: "atender_alerta",
  resuelta: "resolver_alerta",
  falsa_alarma: "falsa_alarma",
  pendiente: "reabrir_alerta",
};

exports.registrarCambioDeAlerta = onDocumentUpdated(
    "alertas/{alertaId}",
    async (event) => {
      const antes = event.data.before.data() || {};
      const despues = event.data.after.data() || {};
      const cambioEstado = antes.estado !== despues.estado;
      const cambioCategoria = (antes.categoria || "") !==
        (despues.categoria || "");
      if (!cambioEstado && !cambioCategoria) return;

      const db = getFirestore();
      const actor = await actorDe(db, antes, despues);
      const base = {
        objetivoTipo: "alerta",
        objetivoUid: event.params.alertaId,
        objetivoNombre: despues.nombreUsuario || "",
        aldea: despues.aldea || "",
      };
      if (cambioEstado) {
        await registrar(db, actor, {
          ...base,
          accion: ACCION_POR_ESTADO[despues.estado] || "cambiar_estado_alerta",
          valorAnterior: {estado: antes.estado || ""},
          valorNuevo: {estado: despues.estado || ""},
        });
      }
      if (cambioCategoria) {
        await registrar(db, actor, {
          ...base,
          accion: "clasificar_alerta",
          valorAnterior: {categoria: antes.categoria || ""},
          valorNuevo: {categoria: despues.categoria || ""},
        });
      }
      logger.info(`Bitácora: alerta ${event.params.alertaId} por ` +
        `${actor.nombre || "desconocido"}.`);
    },
);

/** Campos de la cuenta que se auditan, con su valor por defecto. */
const CAMPOS_USUARIO = {
  estadoCuenta: "aprobado",
  rol: "ciudadano",
  aldea: "",
  nombre: "",
  esResponsable: false,
  puedeVerIdentidad: false,
  contactosConfianza: [],
};

function igual(a, b) {
  return JSON.stringify(a) === JSON.stringify(b);
}

/** Acción principal de un cambio de cuenta (un registro por escritura). */
function accionDeCuenta(cambios, antes, despues) {
  if ("estadoCuenta" in cambios) {
    const de = antes.estadoCuenta || "aprobado";
    const a = despues.estadoCuenta || "aprobado";
    if (de === "pendiente_revision" && a === "aprobado") {
      return "aprobar_usuario";
    }
    if (a === "suspendido") return "suspender_usuario";
    if (de === "suspendido" && a === "aprobado") return "reactivar_usuario";
    return "cambiar_estado_cuenta";
  }
  if ("esResponsable" in cambios) {
    return despues.esResponsable ? "designar_coordinador" :
      "quitar_coordinador";
  }
  if ("puedeVerIdentidad" in cambios) {
    return despues.puedeVerIdentidad ? "delegar_aprobacion" :
      "quitar_aprobacion";
  }
  if ("rol" in cambios) return "cambiar_rol";
  if ("contactosConfianza" in cambios) return "cambiar_contactos_confianza";
  if ("aldea" in cambios) return "cambiar_aldea";
  return "corregir_nombre";
}

exports.registrarCambioDeUsuario = onDocumentUpdated(
    "usuarios/{uid}",
    async (event) => {
      const antes = event.data.before.data() || {};
      const despues = event.data.after.data() || {};

      const cambios = {};
      for (const [campo, defecto] of Object.entries(CAMPOS_USUARIO)) {
        const de = antes[campo] === undefined ? defecto : antes[campo];
        const a = despues[campo] === undefined ? defecto : despues[campo];
        if (!igual(de, a)) cambios[campo] = {de, a};
      }
      if (Object.keys(cambios).length === 0) return;

      // El rechazo lo registra la app con su motivo (y el perfil se borra).
      if ((despues.estadoCuenta || "") === "rechazado") return;

      const db = getFirestore();
      const actor = await actorDe(db, antes, despues);
      const valorAnterior = {};
      const valorNuevo = {};
      for (const [campo, {de, a}] of Object.entries(cambios)) {
        valorAnterior[campo] = de;
        valorNuevo[campo] = a;
      }
      // Los contactos de confianza se guardan con nombres legibles.
      if ("contactosConfianza" in cambios) {
        const nombres = async (ids) => Promise.all((ids || []).map(async (id) => {
          const d = await db.doc(`usuarios/${id}`).get();
          return d.exists ? (d.data().nombre || id) : id;
        }));
        valorAnterior.contactosConfianza =
          await nombres(cambios.contactosConfianza.de);
        valorNuevo.contactosConfianza =
          await nombres(cambios.contactosConfianza.a);
      }

      await registrar(db, actor, {
        accion: accionDeCuenta(cambios, antes, despues),
        objetivoTipo: "usuario",
        objetivoUid: event.params.uid,
        objetivoNombre: despues.nombre || "",
        aldea: despues.aldea || despues.aldeaSolicitada || "",
        valorAnterior,
        valorNuevo,
      });
      logger.info(`Bitácora: usuario ${event.params.uid} por ` +
        `${actor.nombre || "desconocido"}.`);
    },
);
