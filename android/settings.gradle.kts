pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "MadalasaAlarkaAndroid"

// The parent and child workstreams land independently; only include checked-in modules.
// When both worker branches are merged to dev, both projects are available together.
if (file("ui-common/build.gradle.kts").isFile) include(":ui-common")
if (file("madalasa/build.gradle.kts").isFile) include(":madalasa")
if (file("alarka/build.gradle.kts").isFile) include(":alarka")
