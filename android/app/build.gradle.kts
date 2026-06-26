plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.shift_recorder"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // 使用 kotlinOptions 替代 compilerOptions（稳定且兼容 AGP 9.0）
    kotlinOptions {
        jvmTarget = "17"
        languageVersion = "1.8"
        apiVersion = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.shift_recorder"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// 启用 coreLibraryDesugaring（解决 flutter_local_notifications 的问题）
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
