import java.io.File

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

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
    project.evaluationDependsOn(":app")
}

subprojects {
    plugins.withId("com.android.library") {
        val androidExtension = extensions.findByName("android") ?: return@withId
        val namespaceGetter = androidExtension.javaClass.methods.find {
            it.name == "getNamespace" && it.parameterCount == 0
        } ?: return@withId
        val currentNamespace = namespaceGetter.invoke(androidExtension) as? String
        if (!currentNamespace.isNullOrBlank()) {
            return@withId
        }

        val manifestFile = File(project.projectDir, "src/main/AndroidManifest.xml")
        if (!manifestFile.exists()) {
            return@withId
        }

        val manifestText = manifestFile.readText()
        val packageMatch = Regex("""package="([^"]+)"""").find(manifestText)
        val manifestPackage = packageMatch?.groupValues?.getOrNull(1)
        if (manifestPackage.isNullOrBlank()) {
            return@withId
        }

        val namespaceSetter = androidExtension.javaClass.methods.find {
            it.name == "setNamespace" && it.parameterCount == 1
        } ?: return@withId
        namespaceSetter.invoke(androidExtension, manifestPackage)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
