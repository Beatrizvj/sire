# Arquitectura de SIRE (app móvil)

Proyecto Flutter con **Clean Architecture** (orientada a *features*), **Riverpod**
para estado e inyección de dependencias, **GoRouter** con guard de sesión, y
soporte para **Firebase** (Auth, Firestore, FCM) mediante un patrón de
repositorios intercambiables.

## Capas por feature

```
features/<feature>/
├── domain/          Reglas de negocio puras (sin Flutter ni Firebase)
│   ├── entities/        Objetos del negocio
│   ├── repositories/    Contratos (interfaces)
│   └── usecases/        Casos de uso
├── data/            Implementaciones
│   ├── models/          Serialización (JSON / Firestore)
│   └── repositories/    Implementaciones de los contratos (local y Firebase)
└── presentation/    UI
    ├── providers/       Estado con Riverpod (Notifier) + DI
    ├── pages/           Pantallas
    └── widgets/         Componentes de la feature
```

`core/` = infraestructura transversal · `shared/` = widgets compartidos.

## Patrón local ↔ Firebase (clave)

Cada repositorio tiene **dos implementaciones** con la misma interfaz de dominio;
el provider elige según `AppConfig.firebaseEnabled`:

```dart
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AppConfig.firebaseEnabled) return AuthRepositoryFirebase(FirebaseAuth.instance);
  return AuthRepositoryLocal(ref.watch(sharedPreferencesProvider));
});
```

Hoy el flag es `false` → la app corre **100% local** (sin credenciales). Al
conectar Firebase (ver [docs/CONNECT_FIREBASE.md](docs/CONNECT_FIREBASE.md)) se
pone en `true` y **no cambia ni el dominio ni la UI**.

## Estructura

```
lib/
├── main.dart · app.dart
├── core/
│   ├── config/      app_config (flags) · firestore_collections
│   ├── theme/ · router/ (GoRouter + guard + AppShell) · di/ · network/ · error/
│   └── services/    logger · permisos · power_button_bridge · messaging (FCM)
├── shared/widgets/  PlaceholderPage
└── features/
    ├── auth/         login + registro · AuthRepository {Firebase, Local}
    ├── users/        AppUser + roles · UserRepository {Firestore, Local}
    ├── alerts/       SOS · AlertRepository {Firestore, Local} · TriggerSos
    ├── location/     LocationRepository (geolocator + geocoding)
    ├── dashboard/    inicio con indicadores
    ├── maps/         placeholder (Hito 5)
    └── profile/      perfil + cierre de sesión
```

## Flujo de autenticación

```
LoginPage / RegisterPage → AuthController (Riverpod)
      │                          │
      │                    AuthRepository (Firebase | Local)
      ▼                          │
GoRouter.redirect  ◄── refreshListenable(isLoggedIn)
  sin sesión → /login   ·   con sesión → /dashboard
```
El registro además crea el perfil `AppUser` en la colección `usuarios`.

## Flujo del SOS

```
Botón SOS en pantalla ──┐
                        ├─► AlertsController.triggerSos(source, userId)
Botón de encendido ×3 ──┘        │
 (servicio nativo Kotlin)   TriggerSos (usecase)
                                 │
        LocationRepository (GPS + dirección)  →  AlertRepository.saveAlert
                                                     │
                              shared_preferences (v1)  ó  Firestore (`alertas`)
```

## Puente nativo del botón de encendido

Android no permite interceptar `KEYCODE_POWER` sin ser app de sistema/root; se
cuentan las alternancias de pantalla (`ACTION_SCREEN_ON/OFF`). Ver
`android/.../PowerButtonService.kt`, `PowerButtonEvents.kt`, `MainActivity.kt` y
`lib/core/services/power_button_bridge.dart`.

**Límites conocidos:** con pantalla bloqueada o en OEMs que matan procesos la
fiabilidad baja; Android 12+ tiene su propio "SOS" en ese botón. Área de
endurecimiento en hitos posteriores.
