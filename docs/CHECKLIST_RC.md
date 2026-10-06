# SIRE — Versión Candidata a Liberación (10 de octubre de 2026)

> "Versión candidata a liberación con correcciones y mejoras basadas en las
> pruebas." Estado al 6 de octubre de 2026 · versión de la app **1.0.0+2**.

## Entregable de software

- [x] `flutter analyze` sin problemas (6-oct-2026)
- [x] `flutter test` — **47 pruebas** en verde (unit + widget)
- [x] `flutter build apk --release` — APK **1.0.0+2** (~61 MB)
- [x] APK publicado en `https://sire-app-179d3.web.app/descargar.html`
      (QR: [docs/qr-descarga-sire.png](qr-descarga-sire.png))
- [x] Cloud Functions desplegadas en plan **Blaze**: `notificarNuevaAlerta`
      (push FCM) y `notificarWhatsAppNuevaAlerta` (WhatsApp)
- [x] Trabajo en rama `beta/pruebas-preliminares` con commits claros

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

Notas técnicas para la defensa:
- Android **no permite** encender el GPS en silencio desde una app; el estándar
  (Maps, Uber) es el diálogo de un toque (`SettingsClient.checkLocationSettings`).
- La marca de agua aplica a las **fotos nuevas**; las ya subidas no se modifican.

## Pruebas de regresión (6-oct-2026)

| Prueba | Resultado |
|---|---|
| SOS en pantalla → llega push FCM a la Municipalidad | ✅ |
| SOS en pantalla → llega WhatsApp con nombre, categoría, comunidad y enlace de mapa | ✅ |
| Enrutamiento WhatsApp (Municipalidad + Alcaldía Auxiliar, sin COCODE) — prueba con datos simulados | ✅ |
| `flutter analyze` / `flutter test` | ✅ 0 problemas / 47 de 47 |
| SOS con GPS apagado → "Activar" envía con ubicación; "No gracias" envía "Sin ubicación" | ✅ (02-oct-2026) |
| Marca de agua visible en fotos claras y oscuras del DPI | ✅ (02-oct-2026) |

## Observaciones abiertas

- [ ] Se vieron 2 alertas "Sin ubicación" idénticas a la misma hora durante las
      pruebas del GPS (02-oct-2026), con una versión intermedia del código. En el
      código actual cada ruta guarda una sola vez y el botón se bloquea mientras
      envía. **Volver a probar:** 1 SOS en pantalla y 1 por botón de encendido con
      el GPS apagado → debe aparecer exactamente 1 alerta por cada uno.
- [ ] WhatsApp en **sandbox**: cada destinatario debe enviar `join <código>` al
      +1 415 523 8886 y la unión vence a las 72 h. Producción: número propio +
      plantilla aprobada (ver [WHATSAPP_SETUP.md](WHATSAPP_SETUP.md)).

## Antes de entregar

- [ ] Rotar el Auth Token de Twilio y volver a desplegar las funciones
- [ ] Volver a unir al sandbox los teléfonos de las autoridades
- [ ] Borrar datos y cuentas de prueba (p. ej. teléfono 12345678)
- [ ] Etiqueta `v1.0.0-rc1` + `git push` + Pull Request hacia `main`
