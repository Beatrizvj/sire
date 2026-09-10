# SIRE — Activar notificaciones push (FCM)

Deja avisadas a las autoridades (COCODE de la aldea + Municipalidad) cuando
entra una alerta, aunque tengan la app cerrada. Ya está TODO el código listo;
solo falta activarlo cuando el proyecto tenga **plan Blaze**.

## Qué hace
- La app registra el token FCM del dispositivo en `usuarios/{uid}.fcmTokens`.
- La Cloud Function `notificarNuevaAlerta` (en `functions/`) se dispara al crear
  una alerta en `alertas/{id}` y envía la notificación a las autoridades que
  correspondan por rol y aldea.

## Requisitos
- **Plan Blaze** activo (las Cloud Functions y su red saliente lo requieren).
  El uso esperado cae en la capa gratuita; conviene poner una **alerta de
  presupuesto** en Google Cloud.
- Firebase CLI instalado y con sesión: `npm i -g firebase-tools && firebase login`.

## Pasos
1. **Activar Blaze** en la consola de Firebase (Upgrade del proyecto
   `sire-app-179d3`).
2. Encender el flag en la app: en `lib/core/config/app_config.dart` cambia

   ```dart
   static bool get pushEnabled => true;
   ```

3. Desplegar la función (desde la raíz del proyecto):

   ```bash
   firebase deploy --only functions
   ```

   (La primera vez instala dependencias de `functions/` automáticamente.)
4. Recompilar e instalar la app para que registre el token:

   ```bash
   flutter build apk --release
   flutter install --release
   ```

5. **Probar**: inicia sesión como autoridad en un teléfono; desde otra cuenta
   envía un SOS de prueba de esa aldea → debe llegar la notificación
   "🚨 Nueva alerta SOS". Borra los datos de prueba al terminar.

## Notas
- Android 13+ pide permiso de notificaciones la primera vez (ya se solicita).
- iOS necesitaría configuración APNs adicional (no aplica: la app ciudadana es
  Android).
- El **bot de WhatsApp (RF-12)** es un hito aparte: además de Blaze requiere un
  proveedor de WhatsApp Business API (Meta o Twilio) con costo propio por
  mensaje/conversación.
