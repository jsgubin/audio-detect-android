plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.audioapp"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.audioapp"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
        
        // 支持多架构（小米等国产机常用 arm64-v8a 和 armeabi-v7a）
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }
    kotlinOptions {
        jvmTarget = "1.8"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.cardview:cardview:1.0.0")

    // PyTorch Mobile (Android) - 轻量版
    // 如果 1.12.1 找不到，编译时会报错，请改为 1.13.0 或 1.10.0
    implementation("org.pytorch:pytorch_android_lite:1.13.0")

    // JTransforms for FFT
    // 备选坐标（如果 pl.edu.icm 找不到，可尝试 com.github.wendykierp）
    implementation("pl.edu.icm:JTransforms:3.1")
}
