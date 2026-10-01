pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    // Sandbox egress intercepts plugins.gradle.org (DNS 198.18.154.116, marker 303->404)
    // and resets Java TLS to repo.maven.apache.org. Map plugin ids directly to their
    // official Maven modules; google()/mavenCentral() only. The compose compiler plugin
    // has no such module on Central, its marker resolves normally where network allows.
    resolutionStrategy {
        eachPlugin {
            when (requested.id.id) {
                "com.android.application" -> useModule("com.android.tools.build:gradle:${requested.version}")
                "org.jetbrains.kotlin.android",
                "org.jetbrains.kotlin.plugin.serialization" -> useModule("org.jetbrains.kotlin:kotlin-gradle-plugin:${requested.version}")
                "com.google.devtools.ksp" -> useModule("com.google.devtools.ksp:com.google.devtools.ksp.gradle.plugin:${requested.version}")
            }
        }
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "xiao-zhang-gui-android"
include(":app")
