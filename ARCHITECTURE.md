# Arquitectura de SIRE (app móvil)

Proyecto Flutter organizado con **Clean Architecture** (orientada a *features*) y
**Riverpod** para la gestión de estado e inyección de dependencias.

## Capas

Cada *feature* se divide en tres capas con dependencias **hacia adentro**
(presentation → domain ← data):

```
features/<feature>/
├── domain/          Reglas de negocio puras (sin Flutter ni paquetes externos)
│   ├── entities/        Objetos del negocio (SosAlert, LocationReading)
│   ├── repositories/    Contratos (interfaces) que la capa de datos implementa
│   └── usecases/        Casos de uso (TriggerSos)
├── data/            Implementaciones concretas
│   ├── datasources/     Fuentes externas
│   ├── models/          Serialización (JSON/Firestore)
│   └── repositories/    Implementan los contratos del dominio
└── presentation/    UI
    ├── providers/       Estado con Riverpod (Notifier) + inyección de dependencias
    ├── pages/           Pantallas
    └── widgets/         Componentes reutilizables de la feature
```

El código transversal vive en `core/` (tema, router, servicios, red, errores, config).

## Regla de oro
`domain` **no importa** `data` ni `flutter`. Los casos de uso dependen de
*interfaces* (`AlertRepository`, `LocationRepository`); las implementaciones
concretas se inyectan con Riverpod en `presentation/providers`. Así, al pasar de
almacenamiento local a Firestore (Hito 3) **solo cambia la capa `data`**.

## Estructura actual

```
lib/
├── main.dart                     Arranque (ProviderScope + SharedPreferences)
├── app.dart                      MaterialApp.router + tema Material 3
├── core/
│   ├── config/app_config.dart    Constantes y feature flags (Firebase off en v1)
│   ├── theme/                    Tema Material 3 (rojo emergencia)
│   ├── router/                   GoRouter + AppShell (navegación por pestañas)
│   ├── di/app_providers.dart     sharedPreferencesProvider
│   ├── network/dio_client.dart   Cliente HTTP (para hitos con backend)
│   ├── error/                    Failure / Exceptions
│   ├── services/                 logger, permisos, power_button_bridge (nativo)
│   └── widgets/                  PlaceholderPage
└── features/
    ├── alerts/                   ← núcleo SOS (las 3 capas implementadas)
    ├── auth/                     login placeholder (Firebase Auth en Hito 3)
    ├── maps/                     placeholder (Google Maps en Hito 5)
    ├── profile/                  perfil demo
    └── admin/                    placeholder (panel web en Hito 7)
```

## Flujo del SOS

```
Botón SOS en pantalla ──┐
                        ├─► AlertsController.triggerSos(source)
Botón de encendido ×3 ──┘        │
 (servicio nativo Kotlin)        ▼
                          TriggerSos (usecase)
                                 │
              LocationRepository (GPS + dirección, geolocator/geocoding)
                                 │
                          AlertRepository.saveAlert
                                 │
                     shared_preferences (v1)  →  Firestore (Hito 3)
```

## Puente nativo del botón de encendido

Android no permite interceptar `KEYCODE_POWER` sin ser app de sistema/root. Se
cuentan las alternancias de pantalla (`ACTION_SCREEN_ON` / `ACTION_SCREEN_OFF`)
que produce cada pulsación.

- `android/.../PowerButtonService.kt` — foreground service + BroadcastReceiver;
  detecta 3 alternancias en ≤ 5 s.
- `android/.../PowerButtonEvents.kt` — publica el evento al `EventChannel`.
- `android/.../MainActivity.kt` — `MethodChannel sire/power_control` (iniciar/
  detener) y `EventChannel sire/power_events` (recibe `sos_triggered`).
- `lib/core/services/power_button_bridge.dart` — lado Dart del puente.

**Límites conocidos (a endurecer):** con la pantalla bloqueada/apagada o en OEMs
que matan procesos (Xiaomi/Samsung) la fiabilidad baja; Android 12+ tiene su
propio "SOS de emergencia" en el botón; se recomienda exentar de optimización de
batería.
