plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.manukhurana.naam_jap"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.manukhurana.naam_jap"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        val admodAppId = project.findProperties("AD_MOB_Ap_ID_ANDROID")?.toString()
        ? : "ca-app-pub-3940256099942544~3347511713"
        manifestPlaceholders["ANMOB_APP_ID"] = admobAppId
    }

    val keyPorpsFile = rootProject.file("key.properties")
    val hasReleasekey = keyPropsFile.exists();

    if (hasReleasekey) {
        val keyProps = java.util.Properties().apply {
            keyPropsFile.inputStream().use { load(it) }
        }
        signingConfigs {
            create("release") {
                storeFile = file(keyProps["storeFile"] as String)
                storePassword = keyProps["storePassword"] as String
                keyAlias = keyProps["keyAlias"] as String
                keyPassword = keyProps["keyPassword"] as String
            }
        }
    }


    buildTypes {
        release {
            signingConfig = if (hasReleasekey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Shrink optimize and obfuscate native native/java code
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt")
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
