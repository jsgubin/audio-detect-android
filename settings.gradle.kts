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
        // PyTorch Android 和 JTransforms 有些旧版本在 jcenter
        maven { url = uri("https://repo1.maven.org/maven2") }
    }
}

rootProject.name = "AudioDetectOffline"
include(":app")
include(":ringapp")
