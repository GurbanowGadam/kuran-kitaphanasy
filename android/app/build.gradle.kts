import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// Environment overrides ignored android/key.properties. Never fall back to debug signing.
val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.isFile) keyPropertiesFile.inputStream().use { keyProperties.load(it) }
fun signingValue(property: String, environment: String): String? =
    System.getenv(environment)?.takeIf { it.isNotBlank() }
        ?: keyProperties.getProperty(property)?.takeIf { it.isNotBlank() }
val releaseStore = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
val signingValues = listOf(releaseStore, releaseStorePassword, releaseAlias, releaseKeyPassword)
val hasReleaseSigning = signingValues.all { it != null }
require(signingValues.all { it == null } || hasReleaseSigning) {
    "Incomplete release signing: supply all four ANDROID_KEYSTORE_* / ANDROID_KEY_* settings or none."
}
if (hasReleaseSigning) require(rootProject.file(releaseStore!!).isFile) { "Release keystore not found" }

android {
    namespace = "tm.kuran.kitaphanasy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        applicationId = "tm.kuran.kitaphanasy"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        if (hasReleaseSigning) create("production") {
            storeFile = rootProject.file(releaseStore!!)
            storePassword = releaseStorePassword
            keyAlias = releaseAlias
            keyPassword = releaseKeyPassword
        }
    }
    buildTypes {
        debug {
            // Can coexist with both the old demo and the signed production installation.
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            signingConfig = if (hasReleaseSigning) signingConfigs.getByName("production") else null
        }
    }
}
kotlin {
    compilerOptions { jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 }
}
flutter { source = "../.." }
