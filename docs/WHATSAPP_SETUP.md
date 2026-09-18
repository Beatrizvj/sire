# SIRE — Activar el bot de WhatsApp (RF-12)

Envía un aviso por **WhatsApp** a las autoridades (COCODE de la aldea +
Municipalidad) cuando entra una alerta SOS, en paralelo al push. Corre como
Cloud Function y **requiere plan Blaze** (ya activo).

## Qué hace
- La Cloud Function `notificarWhatsAppNuevaAlerta` (en `functions/whatsapp.js`)
  se dispara al crear una alerta en `alertas/{id}`.
- Busca a las autoridades por **rol y aldea** (igual que el push) y lee su campo
  **`telefono`** del perfil (`usuarios/{uid}.telefono`).
- Envía el mensaje por **Twilio** (WhatsApp).
- Si faltan las credenciales, la función **no hace nada** (no-op): se puede
  desplegar sin romper nada.

## Proveedor recomendado para la demo: Twilio (Sandbox de WhatsApp)
El sandbox se activa en minutos y es **gratis** para pruebas — ideal para la
presentación.

### Paso 1 — Crear cuenta Twilio y abrir el sandbox
1. Crea una cuenta gratis en https://www.twilio.com/try-twilio
2. En la consola de Twilio: **Messaging → Try it out → Send a WhatsApp message**.
3. Verás el **Sandbox**: un número (p. ej. `+1 415 523 8886`) y un código tipo
   `join <dos-palabras>`.
4. Cada teléfono que vaya a **recibir** mensajes de prueba debe **unirse una
   vez**: enviar por WhatsApp `join <dos-palabras>` a ese número del sandbox.
   - ⚠️ **Para la demo:** une los teléfonos de las autoridades de prueba al
     sandbox **antes** de presentar.

### Paso 2 — Copiar credenciales (Twilio → Console/Dashboard)
- **Account SID** (empieza con `AC…`)
- **Auth Token**
- Número del sandbox en formato: `whatsapp:+14155238886`

### Paso 3 — Guardar credenciales como *secrets* de Firebase
Desde `C:\dev\sire` (una por una; pega el valor cuando lo pida):

```bash
firebase functions:secrets:set TWILIO_ACCOUNT_SID
firebase functions:secrets:set TWILIO_AUTH_TOKEN
firebase functions:secrets:set TWILIO_WHATSAPP_FROM
```

(`TWILIO_WHATSAPP_FROM` = `whatsapp:+14155238886`, el número del sandbox.)

### Paso 4 — Instalar dependencia y desplegar
```bash
cd functions
npm install twilio
cd ..
firebase deploy --only functions
```

### Paso 5 — Probar
1. Une el teléfono de una autoridad de prueba al sandbox (`join <dos-palabras>`).
2. Envía un SOS de esa aldea desde la app.
3. Debe llegar un WhatsApp: **"🚨 Nueva alerta SOS - SIRE · [nombre] · [categoría] · [aldea]"**.

## Para la demo del sábado
- Muestra el **WhatsApp llegando** al teléfono de la autoridad, junto al push.
- Aclara: en **producción** se usa un número propio de **WhatsApp Business API**
  (Meta o Twilio de pago) con plantilla aprobada, sin el paso de `join`.

## Alternativa: Meta WhatsApp Cloud API
Gratis y con número de prueba, pero requiere crear una app en *Meta for
Developers*, un número de prueba y **plantillas aprobadas** para mensajes
iniciados por el negocio. Son más pasos que Twilio; para la demo, el **sandbox de
Twilio es más rápido**.

## Notas
- **Costo:** el sandbox de Twilio es gratis para pruebas; en producción hay costo
  por conversación (cae dentro del margen esperado para el volumen de SIRE).
- El **flag** `AppConfig.whatsappEnabled` es para funciones del lado de la app en
  hitos futuros; **la Cloud Function se controla por su propia config** (secrets).
- El teléfono se normaliza a formato internacional; los números locales de
  Guatemala (8 dígitos) reciben el prefijo **+502** automáticamente.
