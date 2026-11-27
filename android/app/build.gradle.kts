plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.btaylor.emmaus"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.btaylor.emmaus"
        minSdk = 26
        targetSdk = 36
        versionCode = 2
        versionName = "1.0.1"
        resourceConfigurations += listOf("en")
    }

    // The sideload key lives outside the repository. When it is present, debug
    // and release builds share it, so installing one over the other is an
    // upgrade rather than a signature mismatch. CI has no keystore and falls
    // back to Gradle's debug signing.
    val testKeystore = rootProject.file("emmaus-testing.jks")
    val hasTestKeystore = testKeystore.exists()

    signingConfigs {
        if (hasTestKeystore) {
            create("testing") {
                storeFile = testKeystore
                storePassword = providers.gradleProperty("EMMAUS_KEYSTORE_PASSWORD").getOrElse("emmaus-testing")
                keyAlias = providers.gradleProperty("EMMAUS_KEY_ALIAS").getOrElse("emmaus")
                keyPassword = providers.gradleProperty("EMMAUS_KEY_PASSWORD").getOrElse("emmaus-testing")
            }
        }
    }

    buildTypes {
        debug {
            if (hasTestKeystore) signingConfig = signingConfigs.getByName("testing")
        }
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (hasTestKeystore) signingConfig = signingConfigs.getByName("testing")
        }
    }

    buildFeatures {
        compose = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    implementation(platform("androidx.compose:compose-bom:2024.10.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.activity:activity-compose:1.10.1")
    implementation("androidx.core:core-ktx:1.16.0")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.9.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")

    testImplementation("junit:junit:4.13.2")
    debugImplementation("androidx.compose.ui:ui-tooling")
}
