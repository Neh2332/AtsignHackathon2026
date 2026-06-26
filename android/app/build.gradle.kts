plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.atnav"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.atnav"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

tasks.whenTaskAdded {
    val taskName = name
    if (taskName.startsWith("assemble")) {
        doLast {
            copy {
                from("C:/temp/AtNavBuild/app/outputs/flutter-apk/")
                into(File(projectDir, "../../build/app/outputs/flutter-apk/"))
            }
            copy {
                from("C:/temp/AtNavBuild/app/outputs/flutter-apk/")
                into(File(projectDir, "../../build/app/outputs/apk/debug/"))
            }
            copy {
                from("C:/temp/AtNavBuild/app/outputs/flutter-apk/app-debug.apk")
                into(File(projectDir, "../../build/app/outputs/flutter-apk/"))
                rename("app-debug.apk", "app.apk")
            }
            copy {
                from("C:/temp/AtNavBuild/app/outputs/flutter-apk/app-debug.apk")
                into(File(projectDir, "../../build/app/outputs/apk/debug/"))
                rename("app-debug.apk", "app.apk")
            }
        }
    }
}
