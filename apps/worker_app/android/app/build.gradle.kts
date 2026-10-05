import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val requiredSigningProperties = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val hasReleaseSigning = keystorePropertiesFile.exists() &&
    requiredSigningProperties.all { !keystoreProperties.getProperty(it).isNullOrBlank() }
val releaseArtifactTask = Regex("^(assemble|bundle|install)(.*)Release$", RegexOption.IGNORE_CASE)
val releaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    releaseArtifactTask.matches(taskName.substringAfterLast(':'))
}
if (releaseTaskRequested && !hasReleaseSigning) {
    error("A complete android/key.properties is required to build a signed worker release.")
}
val dartDefines = (findProperty("dart-defines") as? String)
    ?.split(',')
    ?.mapNotNull { encodedDefine ->
        runCatching { String(Base64.getDecoder().decode(encodedDefine), Charsets.UTF_8) }.getOrNull()
    }
    ?.mapNotNull { define ->
        val separator = define.indexOf('=')
        if (separator < 0) null else define.substring(0, separator) to define.substring(separator + 1)
    }
    ?.toMap()
    .orEmpty()
val googleMapsApiKey = dartDefines["GOOGLE_MAPS_API_KEY"]
    ?.takeIf { it.isNotBlank() }
    ?: providers.environmentVariable("GOOGLE_MAPS_API_KEY").orElse("").get()
val hasValidGoogleMapsApiKey = googleMapsApiKey.isNotBlank() &&
    !googleMapsApiKey.startsWith("REPLACE_WITH_") &&
    googleMapsApiKey != "\$(GOOGLE_MAPS_API_KEY)"
if (releaseTaskRequested && !hasValidGoogleMapsApiKey) {
    error("GOOGLE_MAPS_API_KEY is required to build a worker release.")
}
gradle.taskGraph.whenReady {
    val releaseArtifactInGraph = allTasks.any { task ->
        releaseArtifactTask.matches(task.name.substringAfterLast(':'))
    }
    if (releaseArtifactInGraph && !hasReleaseSigning) {
        error("A complete android/key.properties is required to build a signed worker release.")
    }
    if (releaseArtifactInGraph && !hasValidGoogleMapsApiKey) {
        error("GOOGLE_MAPS_API_KEY is required to build a worker release.")
    }
}

android {
    namespace = "com.veedufix.partner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeType = keystoreProperties.getProperty("storeType", "JKS")
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.veedufix.partner"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
