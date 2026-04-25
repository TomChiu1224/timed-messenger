import java.util.Properties

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}

// File: android/app/build.gradle.kts
plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // 🔥 Firebase Google Services Plugin
}

android {
    namespace = "com.example.timed_messenger"
    compileSdk = 35  // ✅ 修復：從34升級到35
    // ✅ 修復：NDK版本從25.1.8937393升級到27.0.12077973
    ndkVersion = "27.0.12077973"

    compileOptions {
        // ─── 改用 Java 11，並且開啟 core library desugaring ───
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // ─── Kotlin 編譯目標也改成 11 ───
        jvmTarget = "11"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID
        applicationId = "com.example.timed_messenger"
        minSdk = 23
        targetSdk = 35  // ✅ 修復：從34升級到35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String
            keyPassword = keyProperties["keyPassword"] as String
            storeFile = file(keyProperties["storeFile"] as String)
            storePassword = keyProperties["storePassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 🔥 Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.16.0"))

    // 🔥 Firebase Analytics
    implementation("com.google.firebase:firebase-analytics")

    // 🔥 Firebase Core (automatically included with BoM)
    //implementation("com.google.firebase:firebase-core")

    // 🔥 Firebase Auth
    implementation("com.google.firebase:firebase-auth")

    // 🔥 Firebase Firestore
    implementation("com.google.firebase:firebase-firestore")

    // 🔥 Firebase Storage
    implementation("com.google.firebase:firebase-storage")

    // 🔥 Firebase Cloud Messaging
    implementation("com.google.firebase:firebase-messaging")

    // ─── 這行讓 Java 8 的 API 可以在舊版 Android 真機/模擬器上用 ───
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.2.2")
}