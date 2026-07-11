# Conectar Firebase (Hito 3)

El código de Firebase (Auth, Firestore, FCM) **ya está escrito**, pero desactivado
por el flag `AppConfig.firebaseEnabled` (getter que hoy devuelve `false`). Mientras
sea `false`, la app usa repositorios **locales** (shared_preferences) y compila/corre
sin credenciales. Estos son los pasos para activarlo.

## 1. Crear el proyecto Firebase
- Entra a <https://console.firebase.google.com> y crea un proyecto (p. ej. `sire-app`).

## 2. Instalar herramientas
```bash
dart pub global activate flutterfire_cli
npm install -g firebase-tools
firebase login
```

## 3. Generar la configuración
```bash
cd C:\dev\sire
flutterfire configure
```
Esto genera `lib/firebase_options.dart` y `android/app/google-services.json`.

## 4. Aplicar el plugin de Google Services (Gradle)
> Necesario **solo** al conectar Firebase; por eso no está aplicado aún (así el
> build de v1 no exige `google-services.json`).

`android/settings.gradle.kts` — dentro del bloque `plugins { … }`:
```kotlin
id("com.google.gms.google-services") version "4.4.2" apply false
```
`android/app/build.gradle.kts` — dentro del bloque `plugins { … }`:
```kotlin
id("com.google.gms.google-services")
```

## 5. Inicializar en `main.dart`
```dart
import 'firebase_options.dart';
// ...
if (AppConfig.firebaseEnabled) {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
```

## 6. Activar el flag
En `lib/core/config/app_config.dart`:
```dart
static bool get firebaseEnabled => true;
```
Con esto, `authRepositoryProvider`, `alertRepositoryProvider` y `userRepositoryProvider`
cambian automáticamente a sus implementaciones de Firebase.

## 7. Consola de Firebase
- **Authentication** → habilitar proveedor **Correo/contraseña**.
- **Firestore Database** → crear en modo producción.
- **Índice compuesto** para el historial de alertas del usuario:
  colección `alertas`, campos `idUsuario` (asc) + `fecha` (desc).
- **Reglas** (borrador inicial por rol):
  ```
  match /alertas/{id} {
    allow create: if request.auth != null;
    allow read, update, delete: if request.auth != null
      && resource.data.idUsuario == request.auth.uid;
  }
  match /usuarios/{uid} {
    allow read, write: if request.auth != null && request.auth.uid == uid;
  }
  ```

## 8. (Hito 4) Notificaciones push
- Llamar `ref.read(messagingServiceProvider).init()` tras iniciar sesión.
- Guardar el token FCM en el documento del usuario.

> Tras estos pasos, ejecuta `flutter run`. Si algo del build nativo de Firebase
> falla (p. ej. desugaring o `minSdk`), avísame con el error y lo ajusto.
