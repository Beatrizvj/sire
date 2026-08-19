plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "gt.edu.miumg.sire"
    compileSdk = flutter.compileSdkVersion
    // AGP exige este NDK en la fase de configuración. Se instaló manualmente en
    // el SDK con descarga reanudable (tools/install_ndk.ps1) por la conexión lenta.
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "gt.edu.miumg.sire"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // SIRE requiere minSdk 24 por el servicio en segundo plano (detección del
        // botón de encendido) y las notificaciones/foreground service modernos.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // SOS nativo del botón de encendido: el servicio en Kotlin escribe la alerta
    // directamente en Firestore. Usa la MISMA BoM que firebase_core (34.15.0),
    // así que reutiliza los artefactos ya descargados (no baja nada nuevo).
    implementation(platform("com.google.firebase:firebase-bom:34.15.0"))
    implementation("com.google.firebase:firebase-firestore")
    // Para leer el usuario autenticado en vivo desde el servicio nativo del SOS.
    implementation("com.google.firebase:firebase-auth")
}

dependencies {
    // ContextCompat.registerReceiver / NotificationCompat para el servicio nativo.
    implementation("androidx.core:core-ktx:1.13.1")
}
