pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        // PyTorch Android 1.10.0 发布在 jcenter，Gradle 7+ 会自动重定向到 Maven Central
        jcenter()
    }
}

rootProject.name = "AudioDetectOffline"
include(":app")
