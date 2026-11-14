import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}
// Firebase is optional for offline builds. Use only the owner's real configuration.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
val releaseKeys = Properties()
val releaseFile = rootProject.file("key.properties")
if (releaseFile.exists()) releaseFile.inputStream().use { releaseKeys.load(it) }
val requestedAbis = (project.findProperty("target-platform") as? String
    ?: "android-arm,android-arm64,android-x64").split(",").mapNotNull {
    when (it) {
        "android-arm" -> "armeabi-v7a"
        "android-arm64" -> "arm64-v8a"
        "android-x64" -> "x86_64"
        else -> null
    }
}

android {
    namespace = "com.rook.shuffleslide"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    // Validation layers are developer tooling and unnecessarily enlarge mobile APKs.
    packaging { jniLibs { excludes += "**/libVkLayer_khronos_validation.so" } }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        applicationId = "com.rook.shuffleslide"
        minSdk = 24
        if (project.findProperty("split-per-abi")?.toString() != "true") {
            ndk { abiFilters.addAll(requestedAbis) }
        }
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        System.getenv("SHUFFLE_DEBUG_KEYSTORE")?.let { path ->
            getByName("debug") { storeFile = file(path) }
        }
        if (releaseFile.exists()) {
            create("release") {
                keyAlias = releaseKeys.getProperty("keyAlias")
                keyPassword = releaseKeys.getProperty("keyPassword")
                storeFile = file(releaseKeys.getProperty("storeFile"))
                storePassword = releaseKeys.getProperty("storePassword")
            }
        }
    }
    buildTypes {
        release {
            if (releaseFile.exists()) signingConfig = signingConfigs.getByName("release")
            // No debug signing fallback for distribution builds.
        }
    }
}
kotlin {
    compilerOptions { jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 }
}
flutter { source = "../.." }
