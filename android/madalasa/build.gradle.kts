plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.compose.compiler)
}

// Non-secret build settings. Use -PmadalasaGoogleWebClientId and -PmadalasaApiOrigin,
// or MA_GOOGLE_WEB_CLIENT_ID and MA_PARENT_API_ORIGIN in the development environment.
// Empty values fail closed: no Google account picker or credential transfer.
val parentWebClientId = providers.gradleProperty("madalasaGoogleWebClientId")
    .orElse(providers.environmentVariable("MA_GOOGLE_WEB_CLIENT_ID")).orNull.orEmpty()
val parentApiOrigin = providers.gradleProperty("madalasaApiOrigin")
    .orElse(providers.environmentVariable("MA_PARENT_API_ORIGIN")).orNull.orEmpty()

android {
    namespace = "org.madalasa.madalasa"
    compileSdk = 36

    defaultConfig {
        // Production release package in.berhampore.madalasa, or overridable via -PmadalasaApplicationId
        applicationId = providers.gradleProperty("madalasaApplicationId").orNull ?: "in.berhampore.madalasa"
        minSdk = 28
        targetSdk = 36
        versionCode = providers.gradleProperty("madalasaVersionCode").map { it.toInt() }.orNull ?: 2
        versionName = providers.gradleProperty("madalasaVersionName").orNull ?: "0.1.0"

        resValue("string", "parent_google_web_client_id", parentWebClientId)
        resValue("string", "parent_api_origin", parentApiOrigin)

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        debug {
            // Preserves synthetic debug package suffix unless overridden
            val customAppId = providers.gradleProperty("madalasaApplicationId").orNull
            if (customAppId == null) {
                applicationIdSuffix = ".synthetic"
            }
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    buildFeatures {
        compose = true
        buildConfig = false
    }
}

dependencies {
    implementation(project(":ui-common"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.credentials)
    implementation(libs.androidx.credentials.play.services.auth)
    implementation(libs.google.id)
    implementation(libs.kotlinx.coroutines.core)

    testImplementation(libs.junit)
    testImplementation("org.json:json:20240303")
    testImplementation(libs.kotlinx.coroutines.test)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.ui.test.junit4)
    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)
}
