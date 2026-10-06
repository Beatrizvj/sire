# SIRE — Activar el bot de WhatsApp (RF-12)

Envía un aviso por **WhatsApp** a las autoridades cuando entra una alerta SOS,
en paralelo al push. Corre como Cloud Function y **requiere plan Blaze** (ya
activo).

## Qué hace
- La Cloud Function `notificarWhatsAppNuevaAlerta` (en `functions/whatsapp.js`)
  se dispara al crear una alerta en `alertas/{id}`.
- Destinatarios (por **rol y aldea**), usando `usuarios/{uid}.telefono`:
  - **Municipalidad**: siempre.
  - **Alcaldía Auxiliar**: si la aldea tiene números en `config/whatsapp_auxiliar`
    (`{ "La Emboscada": ["+502########"] }`), van **solo** esos números, en lugar
    del COCODE (contactos de solo-recepción).
  - **COCODE de la aldea**: solo si la aldea no tiene Alcaldía Auxiliar.
- Proveedor: **Twilio** (demo) o **Meta Cloud API** (`WHATSAPP_PROVIDER`). Si no
  se indica, usa Twilio cuando están sus credenciales.
- Si faltan las credenciales, la función **no hace nada** (no-op): se puede
  desplegar sin romper nada.

## Proveedor para la demo: Twilio (Sandbox de WhatsApp)
El sandbox se activa en minutos y es **gratis** para pruebas.

### Paso 1 — Abrir el sandbox
1. Consola de Twilio: **Messaging → Try it out → Send a WhatsApp message**.
2. Verás el número del sandbox (`+1 415 523 8886`) y un código
   `join <dos-palabras>`.
3. Cada teléfono que vaya a **recibir** mensajes debe enviar por WhatsApp
   `join <dos-palabras>` a ese número.
   - ⚠️ La unión al sandbox **vence a las 72 h**: el día de la demo, vuelve a
     enviar `join …` desde cada teléfono de autoridad **antes** de presentar.

### Paso 2 — Credenciales en `functions/.env` (NO se sube a git)
```
TWILIO_ACCOUNT_SID=AC...
TWILIO_AUTH_TOKEN=...
TWILIO_WHATSAPP_FROM=whatsapp:+14155238886
```
(Ya están cargadas para el sandbox. Para producción conviene migrarlas a Secret
Manager con `firebase functions:secrets:set`.)

### Paso 3 — Desplegar (desde `C:\dev\sire`)
```bash
firebase deploy --only functions
```

### Paso 4 — Probar
1. Revisa que el perfil de la autoridad tenga `telefono` y que ese teléfono se
   haya unido al sandbox.
2. Envía un SOS de esa aldea desde la app.
3. Debe llegar:
   ```
   🚨 Nueva alerta SOS - SIRE
   Ciudadano: …
   Categoría: …
   Comunidad: …
   Ubicación: https://www.google.com/maps?q=…
   ```
4. Revisa el resultado en los logs:
   ```bash
   firebase functions:log --only notificarWhatsAppNuevaAlerta
   ```
   `WhatsApp (Twilio) enviado: N/N` = OK. Error `63015` = el destinatario no se
   unió al sandbox (o venció su unión).

## Producción
- **Twilio**: registrar un número propio como remitente de WhatsApp, crear una
  plantilla en *Content Template Builder* con las variables `{{1}}` nombre,
  `{{2}}` categoría, `{{3}}` comunidad, `{{4}}` ubicación, aprobarla y poner su
  ID en `TWILIO_CONTENT_SID=HX...`.
- **Meta Cloud API** (más barato, sin recargo de Twilio): poner
  `WHATSAPP_PROVIDER=meta` y `WHATSAPP_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`,
  `WHATSAPP_TEMPLATE` (`sire_alerta_sos`), `WHATSAPP_TEMPLATE_LANG` (`es`).
  Requiere cuenta verificada de *Meta for Developers* y plantilla aprobada con
  las mismas 4 variables.

## Notas
- **Costo:** el sandbox es gratis. En producción, ≈ $0.014 por mensaje con Meta y
  ≈ $0.019 con Twilio (tarifa de Meta + $0.005), más el número de Twilio.
- El **flag** `AppConfig.whatsappEnabled` es para funciones del lado de la app en
  hitos futuros; **la Cloud Function se controla por su propia config** (`.env`).
- El teléfono se normaliza a formato internacional; los números locales de
  Guatemala (8 dígitos) reciben el prefijo **+502** automáticamente.
