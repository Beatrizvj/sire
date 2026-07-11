# SIRE — Sistema Integral de Respuesta ante Emergencias

App móvil (Flutter/Android) del proyecto de graduación **SIRE**. Un ciudadano
puede registrarse, iniciar sesión y enviar un **SOS con su ubicación** de dos
formas:

1. **Botón SOS en pantalla.**
2. **3 pulsaciones del botón de encendido** (detección nativa en segundo plano).

> **Modo actual:** la app corre **100% local** (sin Firebase) para poder probar
> de inmediato en un teléfono. El código de **Firebase (Auth, Firestore, FCM) ya
> está escrito** pero desactivado por el flag `AppConfig.firebaseEnabled`. Para
> activarlo: [docs/CONNECT_FIREBASE.md](docs/CONNECT_FIREBASE.md).

## Stack
Flutter · Dart · Riverpod · GoRouter (guard de sesión) · Material 3 ·
geolocator/geocoding · shared_preferences · Firebase Auth · Cloud Firestore ·
Firebase Messaging · Dio · Logger · Clean Architecture · Kotlin (servicio nativo).

## Requisitos
- Flutter (stable) y Android SDK configurados — ver `C:\dev\tools\INSTRUCCIONES.md`.
- Un teléfono Android con **Depuración USB** activada.

## Cómo ejecutar
```bash
flutter pub get
flutter devices          # confirma que tu teléfono aparece
flutter run
```

## Cómo probar
- **Login/Registro:** en modo local cualquier correo y contraseña funcionan;
  el registro guarda el perfil (nombre, teléfono, rol) en el dispositivo.
- **SOS en pantalla:** pestaña **SOS** → botón rojo → concede ubicación → la
  alerta (coordenadas + dirección) aparece en el historial y en el **Inicio**.
- **Botón de encendido:** activa *"Detección por botón de encendido"* → pulsa
  encendido **3 veces en ≤ 5 s** → notificación + alerta registrada.

## Comandos útiles
```bash
flutter analyze          # 0 issues
flutter test             # prueba de humo
flutter build apk --debug
```

## Estructura
Clean Architecture orientada a *features*. Detalle en [ARCHITECTURE.md](ARCHITECTURE.md).

```
lib/core/       transversal (config, tema, router+guard, servicios, red, errores)
lib/shared/     widgets compartidos
lib/features/   auth · users · alerts (SOS) · location · dashboard · maps · profile
android/.../    MainActivity.kt · PowerButtonService.kt · PowerButtonEvents.kt
```

Cada repositorio tiene implementación **local** y **Firebase**, intercambiables
con `AppConfig.firebaseEnabled`.

## Hoja de ruta
| Hito | Contenido | Estado |
|------|-----------|--------|
| 0 | Entorno de desarrollo | ✅ |
| 1 | Estructura Clean Architecture | ✅ |
| 2 | SOS (pantalla + botón físico) + GPS | ✅ v1 |
| 3 | Firebase (Auth + Firestore) | 🟡 código listo, falta conectar |
| 4 | Notificaciones push (FCM) | 🟡 scaffold listo |
| 5 | Google Maps | ⏳ |
| 6 | WhatsApp (Cloud Functions) | ⏳ |
| 7 | Panel web (Flutter Web) | ⏳ |
| 8 | Mapas de calor / analítica | ⏳ |
