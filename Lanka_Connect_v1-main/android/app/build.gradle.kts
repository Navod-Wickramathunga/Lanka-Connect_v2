import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.lanka_connect"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.lanka_connect"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        // Release signing: provide via environment variables or local keystore.properties
        // To set up:
        //   1. Generate a keystore:  keytool -genkey -v -keystore upload-keystore.jks ...
        //   2. Create android/keystore.properties with:
        //        storeFile=../upload-keystore.jks
        //        storePassword=<password>
        //        keyAlias=upload
        //        keyPassword=<password>
        val keystorePropertiesFile = rootProject.file("keystore.properties")
        if (keystorePropertiesFile.exists()) {
            val props = Properties()
            props.load(keystorePropertiesFile.inputStream())
            create("release") {
                storeFile = file(props.getProperty("storeFile"))
                storePassword = props.getProperty("storePassword")
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            val isCiBuild = System.getenv("CI") == "true"
            // CI release builds can fail due to aggressive shrinking on plugin-heavy apps.
            // Keep shrinking for local release builds, disable it in CI for stable APK artifacts.
            isMinifyEnabled = !isCiBuild
            isShrinkResources = !isCiBuild
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            val keystorePropertiesFile = rootProject.file("keystore.properties")
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // Fall back to debug signing when no keystore is configured
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
