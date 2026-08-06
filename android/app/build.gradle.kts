import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase config parser. Needs google-services.json in android/app/.
    id("com.google.gms.google-services")
}

// Upload keystore for Play Store release builds. `android/key.properties`
// is NOT committed (see .gitignore) — each developer / CI must have their
// own copy. If the file is absent, release falls back to debug signing so
// `flutter run --release` still works locally without the real keystore.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.cpnetwork.qr4emergency"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications on Android <26. Backports
        // java.time and other Java 8+ APIs the plugin uses.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.cpnetwork.qr4emergency"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            // Resolve relative to the `android/` folder (rootProject), so
            // `storeFile=upload-keystore.jks` in key.properties finds the
            // file at `android/upload-keystore.jks`. Without rootProject
            // Gradle would look under `android/app/` which is confusing.
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { rootProject.file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Use the real upload keystore when key.properties is present
            // (i.e., you're building for Play Store). Absent → fall back
            // to debug so `flutter run --release` still works locally.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Backport for isCoreLibraryDesugaringEnabled — used by
    // flutter_local_notifications to reach java.time on old Android APIs.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
