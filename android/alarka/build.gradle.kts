plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.compose.compiler)
}

android {
    namespace = "org.madalasa.alarka"
    compileSdk = 36

    defaultConfig {
        // Production package in.berhampore.alarka by default, or overridable via -PalarkaApplicationId
        applicationId = providers.gradleProperty("alarkaApplicationId").orNull ?: "in.berhampore.alarka"
        minSdk = 29
        targetSdk = 36
        versionCode = providers.gradleProperty("alarkaVersionCode").map { it.toInt() }.orNull ?: 1
        versionName = providers.gradleProperty("alarkaVersionName").orNull ?: "0.1.0"

        // Empty by default: release can be installed but cannot falsely activate.
        // Inject a reviewed HTTPS API origin for device/closed tests:
        // ./gradlew :alarka:assembleDebug -PalarkaApiOrigin=https://api.example
        resValue("string", "alarka_api_origin",
            providers.gradleProperty("alarkaApiOrigin").orNull ?: "")

        // Deliberately FALSE until independent legal, Play, Android and
        // deployment signoff; a UI button cannot override this binary gate.
        resValue("bool", "alarka_location_release_approved", "false")
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        debug {
            resValue("bool", "alarka_location_lab_enabled",
                (providers.gradleProperty("alarkaLocationLab").orNull == "true").toString())
        }
        release {
            resValue("bool", "alarka_location_lab_enabled", "false")
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
    implementation(libs.kotlinx.coroutines.core)

    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    debugImplementation(libs.androidx.ui.tooling)
    debugImplementation(libs.androidx.ui.test.manifest)
}
