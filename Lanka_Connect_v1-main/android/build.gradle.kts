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
    if (name == "firebase_messaging") {
        afterEvaluate {
            val typedefRecipe =
                layout.buildDirectory.file(
                    "intermediates/annotations_typedef_file/release/extractReleaseAnnotations/typedefs.txt",
                )

            // AGP validates this release input before firebase_messaging generates it.
            val ensureReleaseTypedefRecipe by tasks.registering {
                outputs.file(typedefRecipe)
                doLast {
                    val output = typedefRecipe.get().asFile
                    if (!output.exists()) {
                        output.parentFile.mkdirs()
                        output.writeText("")
                    }
                }
            }

            tasks.matching { it.name == "syncReleaseLibJars" }.configureEach {
                dependsOn(ensureReleaseTypedefRecipe)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
