plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.dive_app"

    compileSdk = 36
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.dive_app"
        minSdk = 23
        targetSdk = 35

        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        // AGP 8+ 권장: Java 17
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    // 리소스 축소 오류 해결: debug는 축소 끄고, release는 R8+리소스축소 함께 켬
    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = signingConfigs.getByName("debug") // 배포 전 교체
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("com.google.android.gms:play-services-wearable:18.2.0")
    implementation("com.google.android.gms:play-services-location:21.3.0")
}

flutter {
    source = "../.."
}
