import java.util.Properties
import org.gradle.api.tasks.compile.JavaCompile

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningFile = rootProject.file("key.properties")
val releaseRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.substringAfterLast(':').contains("Release", ignoreCase = true)
}
if (releaseRequested && !releaseSigningFile.isFile) {
    error(
        "Android release signing requires android/key.properties with an owner-controlled upload keystore. " +
            "Debug builds do not require this file."
    )
}
val releaseSigning = Properties()
if (releaseSigningFile.isFile) {
    releaseSigningFile.inputStream().use { releaseSigning.load(it) }
    val requiredKeys = listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
    val missingKeys = requiredKeys.filter { releaseSigning.getProperty(it).isNullOrBlank() }
    require(missingKeys.isEmpty()) {
        "Missing Android release signing properties: ${missingKeys.joinToString()}"
    }
    require(file(releaseSigning.getProperty("storeFile")).isFile) {
        "Android release keystore file was not found."
    }
}

android {
    namespace = "com.jevaunharris.onthisday"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.jevaunharris.onthisday"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        multiDexEnabled = true
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (releaseSigningFile.isFile) {
        signingConfigs {
            create("release") {
                keyAlias = releaseSigning.getProperty("keyAlias")
                keyPassword = releaseSigning.getProperty("keyPassword")
                storeFile = releaseSigning.getProperty("storeFile")?.let { file(it) }
                storePassword = releaseSigning.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningFile.isFile) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Flutter 3.41 generates a registrant entry for this dev plugin even though
// its Gradle integration excludes the plugin from the release classpath.
val registrant = file("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
var originalRegistrant: String? = null
val restoreRegistrant = tasks.register("restoreReleasePluginRegistrant") {
    doLast {
        originalRegistrant?.let { registrant.writeText(it) }
    }
}
tasks.withType<JavaCompile>().configureEach {
    if (name == "compileReleaseJavaWithJavac") {
        finalizedBy(restoreRegistrant)
        doFirst {
            val source = registrant.readText()
            val testPlugin = "dev.flutter.plugins.integration_test.IntegrationTestPlugin"
            val registration = Regex(
                """(?m)^    try \{\R      flutterEngine\.getPlugins\(\)\.add\(new dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)\);\R    \} catch \(Exception e\) \{\R      Log\.e\(TAG, "Error registering plugin integration_test, dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin", e\);\R    \}\R"""
            )
            val filtered = source.replace(registration, "")
            check(!filtered.contains(testPlugin)) {
                "Flutter changed integration_test registration; update the release filter."
            }
            if (filtered != source) {
                originalRegistrant = source
                registrant.writeText(filtered)
            }
        }
    }
}
