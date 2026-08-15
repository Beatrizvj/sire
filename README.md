# SIRE — Sistema Integral de Respuesta ante Emergencias

Proyecto de graduación (Universidad Mariano Gálvez). SIRE es una plataforma de
seguridad ciudadana para San Miguel Sigüilá con dos componentes que **comparten
el mismo código Flutter**:

- **App móvil (Android):** el ciudadano se registra, inicia sesión y envía un
  **SOS con su ubicación**.
- **Panel web (COCODE / Municipalidad):** las autoridades reciben las alertas,
  las gestionan y las ven en el mapa. Publicado en
  **https://sire-app-179d3.web.app**.

El SOS se activa de dos formas:

1. **Botón SOS en pantalla.**
2. **3 pulsaciones del botón de encendido** en ≤ 4 s, **sin desbloquear la
   pantalla** (detección nativa en segundo plano), con **8 s para cancelar** y
   evitar falsas alarmas.

> **Estado:** la app está **conectada a Firebase** (proyecto `sire-app-179d3`):
> usa **Firebase Auth** y **Cloud Firestore** reales. Existe además un modo local
> para desarrollo sin conexión, intercambiable con el flag
> `AppConfig.firebaseEnabled` (hoy en `true`).

## Stack
Flutter · Dart · Riverpod · GoRouter (guard de sesión por rol) · Material 3
(tema claro/oscuro) · Firebase Auth · Cloud Firestore · geolocator/geocoding ·
flutter_map (**OpenStreetMap**) · shared_preferences · Dio · Logger ·
Clean Architecture · Kotlin (servicio nativo del botón de encendido).

## Requisitos
- Flutter (stable) y Android SDK configurados.
- Un teléfono Android con **Depuración USB** activada.
- `android/app/google-services.json` (incluido) para la conexión con Firebase.

## Cómo ejecutar
```bash
flutter pub get
flutter devices          # confirma que tu teléfono aparece
flutter run
```

Instalable de la app:   `flutter build apk --release`
Publicar el panel web:  `flutter build web && firebase deploy --only hosting --project sire-app-179d3`

## Cómo probar
- **Registro:** nombre, apellido, teléfono, correo, contraseña, aldea/localidad
  y **dos fotos del DPI** (anverso y reverso). La cuenta queda **pendiente de
  aprobación** por la autoridad.
- **Inicio de sesión / recuperación:** Firebase Auth; enlace *"¿Olvidaste tu
  contraseña?"* que envía un correo para restablecerla; bloqueo temporal tras
  varios intentos fallidos.
- **Roles:** Ciudadano (SOS + Perfil), COCODE y Municipalidad (Bandeja + Mapa +
  aprobaciones).
- **SOS en pantalla:** pestaña **SOS** → botón rojo → concede ubicación → la
  alerta (coordenadas + dirección) llega a la **Bandeja** y al **Mapa** de la
  autoridad.
- **Botón de encendido:** activa *"Detección por botón de encendido"* → pulsa
  encendido **3 veces en ≤ 4 s** → cuenta regresiva de 8 s para cancelar →
  alerta registrada.

## Comandos útiles
```bash
flutter analyze          # 0 issues
flutter test             # prueba de humo
flutter build apk --release
```

## Estructura
Clean Architecture orientada a *features*. Detalle en [ARCHITECTURE.md](ARCHITECTURE.md).

```
lib/core/       transversal (config, tema, router+guard, servicios, red, errores)
lib/shared/     widgets compartidos
lib/features/   auth · users (roles/aprobación) · alerts (SOS) · location ·
                dashboard (panel web) · maps (OSM) · profile · identity (DPI) ·
                audit (bitácora) · incidents (categorías) · reports
android/.../    MainActivity.kt · PowerButtonService.kt · PowerButtonEvents.kt
```

Cada repositorio tiene implementación **local** y **Firebase**, intercambiables
con `AppConfig.firebaseEnabled` (por defecto, Firebase).

## Hoja de ruta
| Hito | Contenido | Estado |
|------|-----------|--------|
| 0 | Entorno de desarrollo | ✅ |
| 1 | Estructura Clean Architecture | ✅ |
| 2 | SOS (pantalla + botón físico) + GPS | ✅ |
| 3 | Firebase (Auth + Firestore) | ✅ conectado |
| 4 | Roles, aprobación de cuentas y fotos del DPI | ✅ |
| 5 | Mapa de alertas (OpenStreetMap) | ✅ |
| 6 | Panel web (Flutter Web) | ✅ desplegado |
| 7 | Notificaciones push (FCM) | ⏳ requiere plan Blaze |
| 8 | Bot de WhatsApp (Cloud Functions) | ⏳ requiere plan Blaze |
| 9 | Mapas de calor / analítica | ⏳ |
