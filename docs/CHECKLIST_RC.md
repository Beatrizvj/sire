# SIRE — Versión Candidata a Liberación (10 de octubre de 2026)

> "Versión candidata a liberación con correcciones y mejoras basadas en las
> pruebas." Estado al 9 de octubre de 2026 · versión de la app **1.0.0+4**.

## Entregable de software

- [x] `flutter analyze` sin problemas (6-oct-2026)
- [x] `flutter test` — **47 pruebas** en verde (unit + widget)
- [x] `flutter build apk --release` — APK **1.0.0+4** (~61 MB)
- [x] APK publicado en `https://sire-app-179d3.web.app/descargar.html`
      (QR: [docs/qr-descarga-sire.png](qr-descarga-sire.png))
- [x] Cloud Functions desplegadas en plan **Blaze**: `notificarNuevaAlerta`
      (push FCM) y `notificarWhatsAppNuevaAlerta` (WhatsApp)
- [x] Página pública con *Acerca de*, uso de WhatsApp, privacidad y contacto
      (`f5b6082`)
- [x] Diagnóstico de entregas de WhatsApp: `node functions/scripts/estado-whatsapp.js`
      (`79bda79`)
- [x] Datos de prueba eliminados (8-oct-2026): quedan 3 cuentas reales, 0 alertas
      y 0 registros de auditoría; respaldo local previo fuera del repositorio
- [x] Trabajo en rama `beta/pruebas-preliminares` con commits claros; etiqueta
      `v1.0.0-rc1`

## Correcciones y mejoras desde la Beta (12-sep-2026)

| # | Origen | Hallazgo / pedido | Corrección o mejora | Commit |
|---|---|---|---|---|
| 1 | Pruebas en web | La foto del DPI no se podía capturar/seleccionar en la consola web | Captura sin `image_cropper` y selector con `<input>` real del DOM, abierto en el gesto del toque | `d8acfe0`, `d0098c1`, `af0da47` |
| 2 | Pruebas en dispositivo | El SOS por botón de encendido fallaba con la app en segundo plano | Servicio nativo más robusto (wake lock, proveedor fusionado + respaldos de ubicación) | `27ddf14` |
| 3 | Pruebas de interfaz | Tarjeta "COCODE de tu aldea" mostraba el texto en vertical | Corrección de diseño de la tarjeta | `45ee730` |
| 4 | Retroalimentación | Los ciudadanos no tenían a quién llamar | Directorio de contactos por rol (teléfonos) en web y app | `03858da` |
| 5 | Asesor (post-Beta) | Riesgo de mal uso de la foto del DPI | **Marca de agua** "SIRE - verificacion de identidad - fecha" horneada en el teléfono antes de subir (el servidor nunca guarda copia limpia) | `785aadb` |
| 6 | Asesor (post-Beta) | Con el GPS apagado el SOS no salía | Diálogo de sistema de **un toque** para activar la ubicación; la alerta se envía **siempre** (con ubicación, última conocida o "Sin ubicación") | `785aadb`, `2922883` |
| 7 | RF-13 | La cuenta regresiva no se veía con el teléfono bloqueado | Pantalla de SOS sobre la pantalla de bloqueo (`SosCountdownActivity`) | `785aadb` |
| 8 | Pendiente de la Beta | Push FCM preparado pero no activo | Plan Blaze + función desplegada; probado en dispositivo | `591b2be` (+ deploy) |
| 9 | Pendiente de la Beta (RF-12) | Bot de WhatsApp no implementado | Cloud Function con **Twilio** (sandbox) o **Meta Cloud API**, enrutamiento por aldea y Alcaldía Auxiliar; probado en dispositivo el 6-oct-2026 | `524a4d0` |
| 11 | Prueba con usuaria nueva (8-oct-2026) | En un teléfono recién instalado, 2 de 3 SOS por **botón de encendido** llegaron **sin ubicación** (los 4 SOS en pantalla sí la llevaban). Causa: la app nunca pedía la ubicación "todo el tiempo"; al reiniciar Android el servicio en segundo plano, este perdía el acceso al GPS | La app pide "Permitir todo el tiempo" al activar la detección (con explicación) y muestra un aviso con **Solucionar** si falta; la captura nativa acepta una posición de hasta 2 min, espera hasta 20 s por GPS y recurre a red celular/wifi antes de la última conocida | `3bfb79d` |
| 12 | Prueba con autoridades (9-oct-2026) | Los auxiliares explicaron que **la Alcaldía Auxiliar es quien vela por la seguridad** de la aldea (más que el COCODE), pero el sistema solo tenía los roles Ciudadano, COCODE y Municipalidad: tuvieron que registrarse como COCODE | Nuevo rol **Alcaldía Auxiliar** con los permisos de autoridad de su aldea (bandeja, mapa, atención, reportes); recibe push; reglas de seguridad y funciones actualizadas | `d9abb3c` |
| 13 | Prueba con autoridades (9-oct-2026) | Pidieron que **5 de ellos aprueben** el registro de los demás integrantes (≈ 50) | Permiso **Responsable** (lo otorga la Municipalidad): aprueba a los integrantes de su aldea como Alcaldía Auxiliar; solo los responsables reciben el **WhatsApp** (≈ Q0.75 por alerta en lugar de ≈ Q7.50); los demás, push gratis. Reglas: nadie salvo la Municipalidad puede otorgarse permisos | `d5597cc` |
| 10 | Pruebas de WhatsApp | El log decía "enviado" aunque el mensaje no llegara (destinatario no unido / ventana de 24 h vencida) | Script de diagnóstico que consulta la entrega real en Twilio por destinatario (errores 63015 / 63016) | `79bda79` |

Notas técnicas para la defensa:
- Android **no permite** encender el GPS en silencio desde una app; el estándar
  (Maps, Uber) es el diálogo de un toque (`SettingsClient.checkLocationSettings`).
- La marca de agua aplica a las **fotos nuevas**; las ya subidas no se modifican.

## Pruebas de regresión (6 al 8-oct-2026)

| Prueba | Resultado |
|---|---|
| SOS en pantalla → llega push FCM a la Municipalidad | ✅ |
| SOS en pantalla → llega WhatsApp con nombre, categoría, comunidad y enlace de mapa | ✅ |
| Enrutamiento WhatsApp (Municipalidad + Alcaldía Auxiliar, sin COCODE) — prueba con datos simulados | ✅ |
| `flutter analyze` / `flutter test` | ✅ 0 problemas / 47 de 47 |
| SOS con GPS apagado → "Activar" envía con ubicación; "No gracias" envía "Sin ubicación" | ✅ (02-oct-2026) |
| Marca de agua visible en fotos claras y oscuras del DPI | ✅ (02-oct-2026) |
| SOS por botón de encendido con ubicación en teléfonos de los auxiliares (tras la corrección #11) | ✅ (09-oct-2026) |
| Sesión de prueba: 4 cuentas nuevas con DPI, 10 SOS (10 de 10 con ubicación), WhatsApp entregado y **leído** por los 2 auxiliares | ✅ (09-oct-2026) |
| `flutter analyze` / `flutter test` tras las mejoras #12 y #13 | ✅ 0 problemas / 54 de 54 |
| Entrega real de WhatsApp a los 2 números de la Municipalidad (diagnóstico Twilio: `delivered`) | ✅ (08-oct-2026) |

## Observaciones abiertas

- [ ] Se vieron 2 alertas "Sin ubicación" idénticas a la misma hora durante las
      pruebas del GPS (02-oct-2026), con una versión intermedia del código. En el
      código actual cada ruta guarda una sola vez y el botón se bloquea mientras
      envía. **Volver a probar:** 1 SOS en pantalla y 1 por botón de encendido con
      el GPS apagado → debe aparecer exactamente 1 alerta por cada uno.
- [ ] WhatsApp en **sandbox**: cada destinatario debe enviar `join <código>` al
      +1 415 523 8886 (QR: [docs/qr-join-sandbox.png](qr-join-sandbox.png)). La
      unión vence a las 72 h y solo se entregan mensajes dentro de las 24 h
      siguientes al último mensaje del teléfono (error 63016).
- [ ] **Número propio en trámite** (puesta en producción): remitente
      +502 5366 2007 "SIRE SMS" registrado en Twilio y plantilla
      `alerta_notificacion_sire` (Utility) enviada a revisión. Meta mantiene la
      cuenta de WhatsApp Business **restringida hasta verificar el negocio**;
      se agregó el sitio web público y se abrió el ticket Twilio #29874390. El
      código ya soporta la plantilla (`TWILIO_CONTENT_SID`): al aprobarse solo
      cambia la configuración, sin modificar el software.

- [ ] La sesión de prueba del 9-oct-2026 se convocó con los COCODE de las 4
      aldeas y la Alcaldía Auxiliar; **asistió solo la Alcaldía Auxiliar** (3
      integrantes). La prueba con los COCODE se reprograma (a distancia, con el
      guion y el enlace de descarga) antes de la entrega del 24-oct-2026.

## Antes de entregar

- [ ] Rotar el Auth Token de Twilio y volver a desplegar las funciones
- [ ] El día de la presentación, 30–60 min antes: `join write-lake` desde cada
      teléfono de autoridad + diagnóstico + SOS de prueba
- [x] Borrar datos y cuentas de prueba (8-oct-2026)
- [x] Etiqueta `v1.0.0-rc1` + `git push` (Pull Request hacia `main` desde GitHub)
