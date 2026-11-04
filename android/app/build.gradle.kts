import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// مفتاح التوقيع: يُقرأ من متغيرات البيئة (يضبطها GitHub Actions) أو من key.properties محلياً.
// إن لم يوجد مفتاح يُستخدم مفتاح debug.
val keystoreProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun signingValue(env: String, prop: String): String? =
    System.getenv(env)?.takeIf { it.isNotBlank() } ?: keystoreProps.getProperty(prop)
val releaseStore: String? = signingValue("ALARAB_KEYSTORE_PATH", "storeFile")

android {
    namespace = "com.alialarab.alarab"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.alialarab.sales"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseStore != null && file(releaseStore).exists()) {
            create("release") {
                storeFile = file(releaseStore)
                storePassword = signingValue("ALARAB_KEYSTORE_PASSWORD", "storePassword")
                keyAlias = signingValue("ALARAB_KEY_ALIAS", "keyAlias")
                keyPassword = signingValue("ALARAB_KEY_PASSWORD", "keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
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
