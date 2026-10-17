# SIRE — Pruebas preliminares de SEGURIDAD (Versión Beta)

**Proyecto:** SIRE — Sistema Integral de Respuesta ante Emergencias
**Fecha de corte:** 11 de septiembre de 2026 · **Entrega Beta:** 12 de septiembre de 2026

Complementa a [PRUEBAS_BETA.md](PRUEBAS_BETA.md) (funcionalidad) con las **pruebas
de seguridad** que exige la rúbrica de la Beta. El modelo es de **defensa en
profundidad**: (1) reglas de Cloud Firestore por **rol** y **estado de cuenta**,
(2) *guard* por rol en la app (router/AppShell), (3) validaciones de entrada, y
(4) autenticación (Firebase Auth).

## Cómo ejecutar estas pruebas

- **Opción A — Simulador de reglas (recomendada, sin datos reales):** Firebase
  Console → **Firestore Database → Reglas → Simulador (Playground)**. Permite
  simular *lectura/escritura* como un usuario autenticado con distinto `uid`,
  `rol`, `estadoCuenta` y `aldea`, y ver **"Permiso concedido / denegado"** sin
  tocar datos de producción.
- **Opción B — Cuentas de prueba por rol** en la app (marcadas como prueba):
  1 ciudadano aprobado, 1 COCODE (aldea A), 1 Municipalidad, y 1 solicitante
  pendiente. **Bórralas al terminar.**

Columna **"Obtenido"** para llenar al ejecutar (✅/❌ + captura).

Referencia de reglas: [`firestore.rules`](../firestore.rules).

---

## A. Control de acceso por rol y estado de cuenta

| # | Caso | Pasos | Resultado esperado | Obtenido |
|---|---|---|---|---|
| S1 | Cuenta **no aprobada** sin acceso | Registrar ciudadano (queda `pendiente_revision`) e iniciar sesión | La app muestra **"Cuenta en revisión"**; toda lectura/escritura sensible (alertas, usuarios) es **denegada** por reglas | |
| S2 | No auto‑aprobarse al registrarse | Intentar crear `usuarios/{miUid}` con `estadoCuenta='aprobado'` | **Denegado** (la regla exige `pendiente_revision` al crear) | |
| S3 | Ciudadano no **escala privilegios** | Como ciudadano, editar su propio doc cambiando `rol→cocode`, `estadoCuenta→aprobado` o `puedeVerIdentidad→true` | **Denegado** (la regla del dueño prohíbe tocar rol/estado/permisos/contactos) | |
| S4 | Ciudadano no entra al **panel de autoridad** | Iniciar sesión como ciudadano en la **web** y en el **móvil** | Web: pantalla **"Panel exclusivo"**; móvil: el *guard* lo manda a **SOS** (no Bandeja/Mapa) | |
| S5 | Solo **Municipalidad** elimina usuarios | Como COCODE/ciudadano intentar borrar un `usuarios/{uid}` | **Denegado** (solo `esMunicipalidad()`) | |

## B. Aislamiento por aldea (mínimo privilegio)

| # | Caso | Pasos | Resultado esperado | Obtenido |
|---|---|---|---|---|
| S6 | COCODE ve **solo su aldea** (alertas) | Como COCODE de aldea A, intentar leer una alerta de aldea B | **Denegado**; la Bandeja/Mapa solo muestran alertas de la aldea A | |
| S7 | COCODE aprueba **solo su aldea** | COCODE A intenta aprobar un solicitante que declaró aldea B | No le aparece / **denegado** (regla `aldeaSolicitada == miAldea`) | |
| S8 | COCODE no asigna roles arbitrarios | COCODE intenta cambiar el `rol` de alguien a `cocode`/`municipalidad` | **Denegado** (solo puede dejar `ciudadano` en su aldea) | |

## C. Alertas SOS

| # | Caso | Pasos | Resultado esperado | Obtenido |
|---|---|---|---|---|
| S9 | Crear alerta **solo a nombre propio** | Intentar crear una alerta con `idUsuario` de **otro** usuario | **Denegado** (`idUsuario == request.auth.uid`) | |
| S10 | No leer alertas ajenas | Ciudadano intenta leer una alerta que no es suya ni de un contacto de confianza asignado | **Denegado** | |
| S11 | Ciudadano solo **cancela** la suya | Ciudadano intenta marcar su alerta como `atendida`/`resuelta` (no `falsa_alarma`) | **Denegado**; solo puede cambiarla a `falsa_alarma` | |

## D. Identidad (DPI)

| # | Caso | Pasos | Resultado esperado | Obtenido |
|---|---|---|---|---|
| S12 | DPI solo para **verificadores** | Autoridad **sin** `puedeVerIdentidad` intenta abrir `identidad/{uid}/fotos` | **Denegado**; con `puedeVerIdentidad=true` → **permitido** | |
| S13 | Cada quien sube **su** DPI | Intentar escribir fotos de DPI en el `uid` de **otro** usuario | **Denegado** (`request.auth.uid == uid`) | |

## E. Auditoría (bitácora inmutable)

| # | Caso | Pasos | Resultado esperado | Obtenido |
|---|---|---|---|---|
| S14 | Auditoría **inmutable** | Intentar **editar o borrar** un documento de `auditoria` | **Denegado** (`update, delete: if false`) | |
| S15 | Solo Municipalidad **lee** la bitácora | Como COCODE/ciudadano intentar leer `auditoria` | **Denegado** (solo `esMunicipalidad()`); el registro guarda actor y hora del **servidor** | |

## F. Catálogos administrables

| # | Caso | Pasos | Resultado esperado | Obtenido |
|---|---|---|---|---|
| S16 | Solo Municipalidad administra catálogos | COCODE/ciudadano intenta escribir en `categorias_incidente` o `aldeas` | **Denegado** (solo `esMunicipalidad()`); `aldeas` es de **lectura pública** para el registro | |

## G. Validaciones y autenticación

| # | Caso | Pasos | Resultado esperado | Obtenido |
|---|---|---|---|---|
| S17 | Política de **contraseña** | Registrar con contraseña `1234` | Rechazada (mínimo 8, con letra y número) | |
| S18 | Validación de **nombre** | Nombre con números/símbolos, letras repetidas o de lista negra ("test", etc.) | Rechazado en cliente **y** en la regla `nombreValido()` | |
| S19 | Registro exige **DPI** | Intentar completar el registro sin las dos fotos del DPI | Bloqueado; si falla la subida, se **revierte** la cuenta de Auth (no queda cuenta sin DPI) | |
| S20 | Cambio de contraseña **reautenticado** | Cambiar contraseña dando una contraseña actual incorrecta | Rechazado (Firebase exige reautenticación) | |

## H. Notas de seguridad del backend

- **Clave de service account REVOCADA:** no hay credenciales privilegiadas en el
  repositorio ni en la app; el acceso se rige por Firebase Auth + reglas.
- **Cifrado en tránsito:** todo el tráfico con Firebase y el Hosting es **HTTPS**.
- **Denegar por defecto:** la última regla `match /{document=**} { allow read,
  write: if false; }` bloquea cualquier ruta no contemplada.
- **Datos de identidad (DPI)** en subcolección privada, legibles solo por
  verificadores autorizados por la Municipalidad (mínimo privilegio).

> **Alcance:** son **pruebas preliminares** de seguridad para la Beta (verifican
> el control de acceso, el aislamiento por rol/aldea y las validaciones). Una
> auditoría completa (pruebas de penetración, análisis de dependencias, etc.)
> corresponde a una fase posterior.
