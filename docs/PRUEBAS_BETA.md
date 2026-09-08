# SIRE — Reporte de pruebas preliminares (Versión Beta)

**Proyecto:** SIRE — Sistema Integral de Respuesta ante Emergencias
**Municipio:** San Miguel Sigüilá, Quetzaltenango
**Fecha de corte:** 8 de septiembre de 2026 · **Entrega Beta:** 12 de septiembre de 2026
**Rama:** `beta/pruebas-preliminares` · **Flutter:** 3.44.6 · **Dart:** 3.12.2

Este documento reúne (A) la auditoría del estado del sistema, (B) las pruebas
automatizadas creadas, (C) el plan de pruebas manual de los flujos críticos y
(D) la matriz de requerimientos. Es la evidencia de "pruebas preliminares" de la
Versión Beta.

---

## A. Auditoría del estado del código

| Chequeo | Comando | Resultado |
|---|---|---|
| Análisis estático | `flutter analyze` | ✅ **No issues found!** |
| Pruebas automatizadas | `flutter test` | ✅ **47 pruebas, todas pasan** |
| Compilación release Android | `flutter build apk --release` | ✅ **APK generado (~56 MB)** |
| Consola web en vivo | `https://sire-app-179d3.web.app` | ✅ **Responde 200** (documento, `flutter_bootstrap.js`, `main.dart.js`, fuentes) |

Backend Firebase de producción (proyecto `sire-app-179d3`): Authentication,
Cloud Firestore, Hosting. `AppConfig.firebaseEnabled = true` → el APK y la
consola web usan el backend real. Reglas de seguridad (`firestore.rules`) con
control de acceso por rol y estado de cuenta.

---

## B. Pruebas automatizadas creadas

Ubicación: `test/unit/` (lógica pura) y `test/widget/` (interfaz). Ejecutar con:

```bash
flutter test
```

### Unitarias (`test/unit/`)

| Archivo | Qué verifica |
|---|---|
| `validators_test.dart` | Validación de nombre (R4: acentos, apóstrofo, guion; rechazo de números/símbolos, letras repetidas y lista negra) y de contraseña (mín. 8 con letra y número). |
| `enums_test.dart` | Conversión tolerante de `UserRole`, `AccountStatus`, `AlertStatus`, `SosSource` (mayúsculas/espacios, fallbacks; `puedeAcceder` solo si aprobado). |
| `sos_alert_test.dart` | `tiempoRespuesta` (atendidaEn − creación), `copyWith` (incl. trazabilidad "atendida por"), y `formatearDuracion`. |
| `sos_alert_model_test.dart` | Serialización JSON de la alerta ida y vuelta, incluida la trazabilidad. |
| `app_user_model_test.dart` | Serialización del perfil (todos los campos) y valores por defecto seguros de documentos antiguos. |
| `users_logic_test.dart` | Ruteo por rol/aldea (mínimo privilegio): `pendientesPara` y `usuariosVisiblesPara`. |

### Widget (`test/widget/`)

| Archivo | Qué verifica |
|---|---|
| `alert_status_chip_test.dart` | El chip de estado muestra la etiqueta correcta. |
| `sos_button_test.dart` | El botón SOS dispara al tocar y se bloquea (con progreso) al enviar. |
| `sos_countdown_test.dart` | **RF-13**: cuenta regresiva de cancelación — cancelar no envía, "enviar ahora" envía y al agotarse el tiempo envía. |
| `test/widget_test.dart` | *Smoke test*: la pantalla de login se dibuja con el botón "Ingresar". |

**Hallazgo corregido gracias a las pruebas:** `SosButton` inicializaba su
`AnimationController` de forma perezosa; si el botón nacía en estado `isSending`
fallaba al liberarse. Se movió la creación a `initState()`.

---

## C. Plan de pruebas manual (flujos críticos)

> **Importante:** se ejecuta contra Firebase de **producción**. Usar cuentas y
> datos **claramente marcados como prueba** (p. ej. nombre "PRUEBA Beta", correo
> `prueba+beta@…`) y **borrarlos al terminar**. No modificar datos reales.

Columna "Obtenido" a llenar durante la ejecución (✅/❌ + captura).

| # | Caso | Precondición | Pasos | Resultado esperado | Obtenido |
|---|---|---|---|---|---|
| 1 | Registro con DPI | Sin sesión | Registrarse con nombre/teléfono/correo/contraseña, elegir aldea y tomar foto **anverso y reverso** del DPI → "Crear cuenta" | Cuenta creada **"en revisión"**; perfil en `usuarios` con `estadoCuenta=pendiente_revision`; fotos en `identidad/{uid}/fotos` | |
| 2 | Registro sin DPI (negativo) | Sin sesión | Llenar todo pero **no** tomar las fotos → "Crear cuenta" | Se bloquea y pide las dos fotos del DPI | |
| 3 | Contraseña débil (negativo) | Sin sesión | Contraseña `1234` | Rechaza: mínimo 8 con letra y número | |
| 4 | Login correcto | Cuenta aprobada | Ingresar correo + contraseña | Entra a su inicio según rol (ciudadano→SOS, autoridad→panel) | |
| 5 | Login incorrecto (negativo) | — | Contraseña equivocada | Mensaje claro de error; no entra | |
| 6 | Cuenta pendiente no accede | Cuenta `pendiente_revision` | Iniciar sesión | Queda bloqueada (sin acceso a funciones) hasta ser aprobada | |
| 7 | Aprobación de cuenta | Autoridad (COCODE/Municipalidad) con solicitud pendiente en su aldea | Aprobaciones → Revisar → asignar rol y aldea → Aprobar | Cuenta pasa a `aprobado`; queda registro en `auditoria` (quién y cuándo) | |
| 8 | Verificación de identidad (Ver DPI) | Consola web, actor con `puedeVerIdentidad` | Usuarios → "Ver DPI" del solicitante | Muestra las fotos del DPI para validar identidad | |
| 9 | SOS desde botón en pantalla | Ciudadano aprobado, GPS activo | Pulsar **SOS** → elegir categoría → esperar/omitir la **cuenta regresiva** | Se crea la alerta (estado `pendiente`) con ubicación; aparece en el historial | |
| 10 | Cancelar SOS en la cuenta regresiva | Igual que #9 | Pulsar **SOS** → **CANCELAR** en la cuenta regresiva | **No** se envía ninguna alerta | |
| 11 | SOS por botón de encendido | Android real, detección activada, permisos de ubicación/ notificaciones | Pulsar el botón físico **3 veces** en 4 s | Se genera la alerta (origen "Botón de encendido") aun con la pantalla apagada | |
| 12 | Enrutamiento por aldea | Alerta de un ciudadano de la aldea X | Iniciar sesión como COCODE de X y como COCODE de Y | El COCODE de **X ve** la alerta; el de **Y no**; la Municipalidad la ve siempre | |
| 13 | Atención en bandeja + trazabilidad | Autoridad con alerta pendiente | Bandeja → abrir alerta → **Atender** | Estado pasa a "Atendida"; se registra **"Atendida por [nombre]"** y la hora | |
| 14 | Alarma de alerta nueva (RF-14) | Consola web/autoridad abierta | Enviar un SOS de prueba desde otro dispositivo | Suena la sirena y aparece el aviso rojo "NUEVA ALERTA" | |
| 15 | Mapa de calor | Autoridad, varias alertas con ubicación | Mapa → "Mapa de calor" | Las zonas con más incidentes se ven más intensas (ámbar→rojo); alternar a "Marcadores" muestra pines | |
| 16 | Reportes y exportación | Autoridad | Reportes → elegir rango → exportar **CSV**, **Excel** y **PDF** | Se descargan los 3 archivos con las columnas (incl. "Atendida por" y "Tiempo de respuesta") | |
| 17 | Categorías de incidente | Municipalidad | Configuración → agregar/activar/desactivar categoría | El selector del ciudadano refleja las categorías activas | |
| 18 | Limpieza de datos de prueba | Fin de las pruebas | Borrar usuarios/alertas de prueba (perfil + fotos DPI desde el panel; cuenta Auth desde consola Firebase) | No queda dato de prueba en producción | |

---

## D. Matriz de requerimientos (estado a la fecha)

Leyenda: ✅ implementado · ⚠️ parcial · ❌ pendiente. La numeración RF/RNF es la
inferida del código; confirmar contra el Capítulo IV.

| Funcionalidad | Estado | Nota |
|---|---|---|
| Registro con verificación de identidad (foto DPI obligatoria, con rollback) | ✅ | |
| Login y manejo de errores; bloqueo de cuentas sin perfil/no aprobadas | ✅ | |
| SOS desde botón en pantalla + cuenta regresiva de cancelación (RF-13) | ✅ | |
| SOS por botón de encendido (3 pulsaciones, servicio nativo Kotlin) | ✅ | |
| Enrutamiento de alerta por aldea al COCODE | ✅ | |
| Bandeja / atención de alertas | ✅ | |
| Trazabilidad "atendida por [nombre]" | ✅ | **Nuevo en esta fase** |
| Aprobación de cuentas (móvil y web) + auditoría | ✅ | |
| Gestión de usuarios, roles y comunidad | ✅ | |
| Permiso de verificador `puedeVerIdentidad` + "Ver DPI" | ✅ | En consola web |
| Contactos de confianza (grupos mutuos) | ✅ | |
| Categorías de incidente (catálogo configurable) | ✅ | |
| Mapa de calor de incidentes | ✅ | **Ahora también en la app móvil** (antes solo en web) |
| Reportes con exportación CSV/Excel/PDF + BI | ✅ | |
| Auditoría (bitácora inmutable) | ✅ | |
| Alarma de alerta nueva (RF-14) | ✅ | |
| Notificaciones push (FCM) | ⚠️ | Cliente preparado; envío/registro de token requiere Cloud Function (plan Blaze). El aviso en vivo lo cubre la alarma in-app + servicio nativo. |
| Bot de WhatsApp (RF-12) | ❌ | Requiere plan Blaze + Cloud Function + proveedor de WhatsApp Business API. |
| Seguridad (reglas Firestore por rol/estado, validaciones) — RNF | ✅ | |

---

## E. Reproducir la compilación

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
# APK en: build/app/outputs/flutter-apk/app-release.apk
```
