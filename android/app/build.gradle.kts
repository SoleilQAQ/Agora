import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 加载本地 key.properties（本地开发用，可选）
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasLocalKeystore = keystorePropertiesFile.exists()
if (hasLocalKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// CI 环境变量（GitHub Actions 会写进来）
val ciKeystoreFile: String? = System.getenv("KEYSTORE_FILE")
val ciKeystorePassword: String? = System.getenv("KEYSTORE_PASSWORD")
val ciKeyAlias: String? = System.getenv("KEY_ALIAS")
val ciKeyPassword: String? = System.getenv("KEY_PASSWORD")

android {
    namespace = "com.soleil.agora"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        create("release") {
            when {
                // 1) CI 场景：优先使用环境变量
                !ciKeystoreFile.isNullOrEmpty()
                        && !ciKeystorePassword.isNullOrEmpty()
                        && !ciKeyAlias.isNullOrEmpty()
                        && !ciKeyPassword.isNullOrEmpty() -> {
                    println("Using CI keystore from env variables")
                    storeFile = file(ciKeystoreFile)
                    storePassword = ciKeystorePassword
                    keyAlias = ciKeyAlias
                    keyPassword = ciKeyPassword
                }

                // 2) 本地场景：使用 key.properties
                hasLocalKeystore -> {
                    println("Using local keystore from key.properties")
                    val storePath = keystoreProperties["storeFile"] as String
                    storeFile = file(storePath)
                    storePassword = keystoreProperties["storePassword"] as String
                    keyAlias = keystoreProperties["keyAlias"] as String
                    keyPassword = keystoreProperties["keyPassword"] as String
                }

                // 3) 都没有：提醒但不崩（你也可以在这里直接 throw）
                else -> {
                    println("⚠️ No signing config found for release. " +
                            "Define env vars (KEYSTORE_FILE/KEYSTORE_PASSWORD/KEY_ALIAS/KEY_PASSWORD) " +
                            "or provide android/key.properties.")
                }
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.soleil.agora"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
