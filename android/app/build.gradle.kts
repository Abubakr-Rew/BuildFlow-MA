import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Release signing ─────────────────────────────────────────
// android/key.properties is not in git: see key.properties.example and README «Release-ключ».
// Without it a release build fails; it is never signed with the debug key. Debug builds don't need it.
val keystorePropertiesFile: File = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) keystorePropertiesFile.inputStream().use { load(it) }
}

/** `storeFile` relative to android/app, absolute, or starting with `~/` (home folder). */
fun keystoreFile(path: String): File =
    if (path.startsWith("~/") || path.startsWith("~\\")) {
        File(System.getProperty("user.home"), path.substring(2))
    } else {
        file(path)
    }

/** Why the release can't be signed, or null when key.properties is complete. */
val releaseSigningProblem: String? = run {
    if (!keystorePropertiesFile.exists()) return@run "${keystorePropertiesFile.path} not found."
    val missing = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .filter { keystoreProperties.getProperty(it).isNullOrBlank() }
    if (missing.isNotEmpty()) return@run "${keystorePropertiesFile.path} has no ${missing.joinToString()}."
    val store = keystoreFile(keystoreProperties.getProperty("storeFile").trim())
    if (!store.isFile) return@run "Keystore ${store.path} (storeFile in key.properties) not found."
    null
}

android {
    namespace = "com.abubakr.buildflow"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Changing it makes a separate app: phones keep the old one, with its session and data.
        applicationId = "com.abubakr.buildflow"
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

    signingConfigs {
        if (releaseSigningProblem == null) {
            create("release") {
                storeFile = keystoreFile(keystoreProperties.getProperty("storeFile").trim())
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Left unset without a key: the check below stops the build first.
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// A release build (flutter build apk / appbundle, flutter run --release) without a usable key stops here,
// before the minutes of Dart compilation (compileFlutterBuildRelease runs first).
tasks.matching { it.name == "preReleaseBuild" || it.name == "compileFlutterBuildRelease" }.configureEach {
    val problem = releaseSigningProblem
    doFirst {
        if (problem != null) {
            throw GradleException(
                "Release signing: $problem\n" +
                    "Copy android/key.properties.example to android/key.properties and fill it in, " +
                    "see README, section «Release-ключ». Debug builds don't need a key.",
            )
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
