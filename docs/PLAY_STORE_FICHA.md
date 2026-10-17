# SIRE — Ficha de Google Play y formulario de Seguridad de los datos

Basado en `web/privacidad.html`, `pubspec.yaml` y `AndroidManifest.xml` (v1.0.0+7).

---

## 1. Ficha de la tienda (Presencia en la tienda → Ficha principal)

**Nombre de la app** (máx. 30) — 23 caracteres
```
SIRE San Miguel Sigüilá
```

**Descripción breve** (máx. 80) — 76 caracteres
```
Alertas SOS para San Miguel Sigüilá: envía tu ubicación a las autoridades.
```

**Descripción completa** (máx. 4000)
```
SIRE (Sistema Integral de Respuesta ante Emergencias) es la app oficial de alertas de emergencia para los vecinos de San Miguel Sigüilá, Quetzaltenango, Guatemala.

Con un solo toque puedes pedir ayuda: SIRE envía tu ubicación y el tipo de emergencia a las autoridades de tu aldea para que lleguen lo antes posible.

FUNCIONES PRINCIPALES
• Botón SOS: envía una alerta con tu ubicación GPS en segundos.
• SOS con el botón de encendido: pide ayuda presionando el botón de encendido de tu teléfono, incluso con la pantalla bloqueada.
• Categorías de emergencia: indica si se trata de un incendio, accidente, emergencia médica, inseguridad u otra situación.
• Aviso inmediato a las autoridades: la Municipalidad, el COCODE y la Alcaldía Auxiliar de tu aldea reciben la alerta por notificación y WhatsApp.
• Seguimiento: consulta el estado de tus alertas y quién las está atendiendo.
• Registro verificado: cada usuario verifica su identidad con su DPI, lo que evita alertas falsas.
• Panel para autoridades: el personal autorizado ve las alertas en un mapa, las atiende y genera reportes.

PRIVACIDAD Y SEGURIDAD
• Tu ubicación solo se usa cuando envías un SOS.
• Las fotos de tu DPI llevan marca de agua y solo las ven los verificadores autorizados.
• Los datos se guardan cifrados y no se venden ni se comparten con terceros.
• Puedes eliminar tu cuenta en cualquier momento desde la app.

SIRE es un proyecto de la Universidad Mariano Gálvez de Guatemala en coordinación con la Municipalidad de San Miguel Sigüilá.

IMPORTANTE: SIRE complementa, pero no reemplaza, los números de emergencia oficiales (Bomberos 122/123, PNC 110).
```

**Otros campos**
- Categoría: **Herramientas** (o *Estilo de vida*). Etiquetas: *Seguridad*, *Emergencias*.
- Correo de contacto: el correo de soporte del equipo.
- Sitio web: `https://siresanmiguel.com`
- Política de privacidad: `https://siresanmiguel.com/privacidad.html`
- Gráficos: ícono 512×512 PNG, gráfico de funciones 1024×500 y al menos 2 capturas de teléfono (de 1080×1920 en adelante).

---

## 2. Formulario de Seguridad de los datos (Contenido de la app → Seguridad de los datos)

### Paso 1: Resumen
| Pregunta | Respuesta |
|---|---|
| ¿Tu app recopila o comparte alguno de los tipos de datos del usuario requeridos? | **Sí** |
| ¿Todos los datos recopilados se encriptan en tránsito? | **Sí** (Firebase usa HTTPS/TLS) |
| ¿Proporcionas una forma para que los usuarios soliciten que se borren sus datos? | **Sí** → URL: `https://siresanmiguel.com/eliminar-cuenta.html` |

### Paso 2: Tipos de datos (marcar **solo** estos)
| Categoría Play | Tipo | Qué es en SIRE |
|---|---|---|
| Ubicación | **Ubicación precisa** | GPS del SOS |
| Ubicación | **Ubicación aproximada** | Se declara porque el manifiesto pide `ACCESS_COARSE_LOCATION` |
| Información personal | **Nombre** | Registro |
| Información personal | **Dirección de correo electrónico** | Inicio de sesión (Firebase Auth) |
| Información personal | **Números de teléfono** | Registro / contacto |
| Información personal | **Otra información** | Aldea y número de DPI |
| Fotos y videos | **Fotos** | Fotos del DPI |
| Actividad en la app | **Otro contenido generado por el usuario** | Alertas SOS (categoría, fecha, estado) |
| ID del dispositivo u otros ID | **ID del dispositivo u otros ID** | Token de FCM para notificaciones |

No marcar: información financiera, salud, mensajes, audio, archivos, calendario, contactos, historial web, Analytics ni Diagnóstico (salvo que agregues Crashlytics o Analytics).

### Paso 3: Detalle por tipo de dato
Para cada tipo marcado, Play pregunta lo mismo. Respuestas:

| Tipo | ¿Recopilado? | ¿Compartido?* | ¿Efímero? | ¿Obligatorio u opcional? | Finalidades |
|---|---|---|---|---|---|
| Ubicación precisa | Sí | No | No | **Obligatorio** | Funcionalidad de la app |
| Ubicación aproximada | Sí | No | No | Obligatorio | Funcionalidad de la app |
| Nombre | Sí | No | No | Obligatorio | Funcionalidad de la app; Administración de la cuenta |
| Correo | Sí | No | No | Obligatorio | Administración de la cuenta |
| Teléfono | Sí | No | No | Obligatorio | Funcionalidad de la app; Administración de la cuenta |
| Otra información (aldea, DPI) | Sí | No | No | Obligatorio | Funcionalidad de la app; Prevención de fraudes, seguridad y cumplimiento |
| Fotos (DPI) | Sí | No | No | Obligatorio | Prevención de fraudes, seguridad y cumplimiento; Administración de la cuenta |
| Otro contenido del usuario (alertas) | Sí | No | No | Obligatorio | Funcionalidad de la app |
| ID del dispositivo (token FCM) | Sí | No | No | Obligatorio | Funcionalidad de la app |

\* **"Compartido" = No.** Para Google, enviar datos a *proveedores de servicios* que los procesan en tu nombre (Firebase/Google, Twilio, Meta para WhatsApp) **no cuenta como compartir**. Tampoco cuenta mostrarlos a las autoridades municipales, porque son los operadores del propio servicio. Esto coincide con la política: "no se venden ni se comparten con terceros".

---

## 3. Otras declaraciones obligatorias (Contenido de la app)

SIRE pide permisos sensibles, así que Play exigirá estas declaraciones **antes** de aprobar la versión:

1. **Ubicación en segundo plano** (`ACCESS_BACKGROUND_LOCATION`) — **la más delicada**
   - Justificación: *"El usuario puede enviar un SOS presionando el botón de encendido con la pantalla bloqueada. En ese momento la app está en segundo plano y necesita obtener la ubicación para enviarla a las autoridades. La ubicación solo se obtiene al disparar un SOS; no se rastrea de forma continua."*
   - Hay que subir un **video de 30 s o menos** (YouTube no listado) que muestre la divulgación previa dentro de la app, el permiso del sistema y un SOS enviado con la pantalla bloqueada.
   - La app debe mostrar un **aviso destacado** antes de pedir el permiso, con un texto como *"SIRE recopila tu ubicación para enviar alertas SOS, incluso cuando la app está cerrada o no está en uso."*
2. **Servicios en primer plano** (`FOREGROUND_SERVICE_LOCATION` y `FOREGROUND_SERVICE_SPECIAL_USE`): describe "detección del botón de encendido para SOS de emergencia" e incluye un video.
3. **Intent de pantalla completa** (`USE_FULL_SCREEN_INTENT`): declarar como *alarmas/emergencias* (aviso de alerta entrante a las autoridades).
4. **Clasificación del contenido**: cuestionario IARC, categoría *Utilidad/Productividad*. Responde "No" a violencia, sexo, etc. y "Sí" a "comparte la ubicación del usuario con otros usuarios", porque las autoridades la ven. Resultado esperado: *Para todos* o *PEGI 3*.
5. **Público objetivo**: **18+** (el registro requiere DPI). Así no se aplica la política de familias.
6. **Anuncios**: No. **Acceso a la app**: Play necesita credenciales de prueba. Crea una cuenta de revisor ya verificada y anota usuario y contraseña en *Acceso a la app*, porque el revisor no puede pasar la verificación de DPI.
7. **App gubernamental**: si Play pregunta, responde que **no** es una app oficial del gobierno, sino un proyecto académico en coordinación con la municipalidad. Responder "sí" exige documentación oficial.
