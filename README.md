# SIRE — Sistema Integral de Respuesta ante Emergencias

App móvil (Flutter/Android) del proyecto de graduación **SIRE**. Permite a un
ciudadano enviar un **SOS con su ubicación** de dos formas:

1. **Botón SOS en pantalla.**
2. **3 pulsaciones del botón de encendido** (detección nativa en segundo plano).

> **v1 (esta versión):** funciona **100 % local** (sin Firebase) para poder
> probar de inmediato en un teléfono. La nube (Firebase), Google Maps, WhatsApp
> y el panel web llegan en hitos posteriores. Ver [ARCHITECTURE.md](ARCHITECTURE.md).

## Stack
Flutter · Dart · Riverpod · GoRouter · Material 3 · geolocator/geocoding ·
shared_preferences · Dio · Logger · Clean Architecture · Kotlin (servicio nativo).

## Requisitos
- Flutter (stable) y Android SDK configurados — ver `C:\dev\tools\INSTRUCCIONES.md`.
- Un teléfono Android con **Depuración USB** activada.

## Cómo ejecutar
```bash
flutter pub get
flutter devices          # confirma que tu teléfono aparece
flutter run              # instala y ejecuta en el dispositivo
```

## Cómo probar el SOS
- **En pantalla:** pulsa el botón rojo **SOS** → concede el permiso de ubicación
  → verás la alerta (lat/lng + dirección) en el historial.
- **Botón de encendido:** activa el interruptor *"Detección por botón de
  encendido"* (concede la notificación), luego **pulsa el botón de encendido 3
  veces en ≤ 5 s**. Aparece una notificación y se registra el SOS.

## Comandos útiles
```bash
flutter analyze          # análisis estático (0 issues)
flutter test             # prueba de humo
flutter build apk --debug
```

## Estructura
Clean Architecture orientada a *features*. Detalle en [ARCHITECTURE.md](ARCHITECTURE.md).

```
lib/core/       transversal (tema, router, servicios, red, errores)
lib/features/   alerts (SOS), auth, maps, profile, admin
android/.../    MainActivity.kt, PowerButtonService.kt, PowerButtonEvents.kt
```

## Hoja de ruta
| Hito | Contenido | Estado |
|------|-----------|--------|
| 0 | Entorno de desarrollo | ✅ |
| 1 | Estructura Clean Architecture | ✅ |
| 2 | SOS (pantalla + botón físico) + GPS | ✅ v1 |
| 3 | Firebase (Auth + Firestore) | ⏳ |
| 4 | Notificaciones push (FCM) | ⏳ |
| 5 | Google Maps | ⏳ |
| 6 | WhatsApp (Cloud Functions) | ⏳ |
| 7 | Panel web (Flutter Web) | ⏳ |
| 8 | Mapas de calor / analítica | ⏳ |
