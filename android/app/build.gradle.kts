// android/app/build.gradle.kts

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")   // musi być ostatnia
}

android {
    namespace   = "com.example.techiot_admin"
    compileSdk  = 35
    ndkVersion  = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions { jvmTarget = "11" }

    defaultConfig {
        applicationId = "com.example.techiot_admin"
        minSdk        = 24
        targetSdk     = 35
        versionCode   = flutter.versionCode
        versionName   = flutter.versionName
    }

    /* ───────────── PODPISYWANIE RELEASE ───────────── */
    signingConfigs {
        create("release") {
            // plik leży w android/app/ — dlatego wystarczy nazwa
            storeFile     = file("upload-keystore.jks")
            storePassword = "Zepetlens1!@"
            keyAlias      = "upload"
            keyPassword   = "Zepetlens1!@"
            // jeśli wygenerowałeś .jks → domyślnie JKS, więc storeType można pominąć
            // storeType  = "jks"
        }
    }
    buildTypes {
        release {
            signingConfig     = signingConfigs.getByName("release")
            isMinifyEnabled   = false      // zostaw false (szybszy build, brak R8)
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
