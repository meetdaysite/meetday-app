allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.google.android.libraries.places" && requested.name == "places") {
                useVersion("3.5.0")
                because("flutter_google_places_sdk_android 0.2.2 uses the Places 3.x Android API")
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
