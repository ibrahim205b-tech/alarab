import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// مفتاح التوقيع: يُقرأ من متغيرات البيئة (GitHub Secrets) إن وُجدت،
// وإلا يُستخدم المفتاح المرفق بالمشروع حتى تبقى التحديثات قابلة للتثبيت فوق النسخة السابقة.
val keystoreProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun signingValue(env: String, prop: String, fallback: String): String =
    System.getenv(env)?.takeIf { it.isNotBlank() } ?: keystoreProps.getProperty(prop) ?: fallback

android {
    namespace = "com.alialarab.alarab"
    compileSdk = flutter.compileSdkVersion
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
        create("release") {
            storeFile = file(signingValue("ALARAB_KEYSTORE_PATH", "storeFile", "alarab-release.jks"))
            storePassword = signingValue("ALARAB_KEYSTORE_PASSWORD", "storePassword", "alarab2026")
            keyAlias = signingValue("ALARAB_KEY_ALIAS", "keyAlias", "alarab")
            keyPassword = signingValue("ALARAB_KEY_PASSWORD", "keyPassword", "alarab2026")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
