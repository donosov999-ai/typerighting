plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "pro.typefree.candidate.typefree_flutter_foundation"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        // Same-ID update tests only: -PtypefreeAppId=pro.typefree.app. Without the
        // property the build stays the isolated candidate.
        applicationId = (project.findProperty("typefreeAppId") as String?)
            ?: "pro.typefree.candidate.typefree_flutter_foundation"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Same-ID update tests only: a local test keystore (never a store key)
    // via -PtypefreeTestKeystore=<path> -PtypefreeTestKeyPassword=<pw>.
    val testKeystore = project.findProperty("typefreeTestKeystore") as String?
    signingConfigs {
        if (testKeystore != null) {
            create("updateTest") {
                storeFile = file(testKeystore)
                storePassword = project.findProperty("typefreeTestKeyPassword") as String
                keyAlias = "typefreetest"
                keyPassword = project.findProperty("typefreeTestKeyPassword") as String
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = if (testKeystore != null) {
                signingConfigs.getByName("updateTest")
            } else {
                signingConfigs.getByName("debug")
            }
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
