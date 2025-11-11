plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter plugin MUST come after Android/Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.mic_to_speaker"        // <-- your final package
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17   // Kotlin DSL syntax
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"                               // Kotlin DSL: use string
    }

    defaultConfig {
        applicationId = "com.example.mic_to_speaker"    // <-- same as namespace
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // dev only: debug keystore; change for production
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    // TarsosDSP later (if you add effects via this lib):
    // implementation("com.github.JorenSix:TarsosDSP:2.5")
}

flutter {
    source = "../.."
}
