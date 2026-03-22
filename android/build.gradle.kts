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
    afterEvaluate {
        val androidExt = project.extensions.findByName("android")
        if (androidExt != null) {
            val hasNamespace = try {
                androidExt.javaClass.getMethod("getNamespace").invoke(androidExt) != null
            } catch (e: Exception) { false }

            if (!hasNamespace) {
                try {
                    val method = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                    var ns = project.group.toString()
                    if (ns.isEmpty() || ns == "null") {
                        ns = "com.pichillilorenzo.flutter_inappwebview"
                    }
                    val manifestFile = project.file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val text = manifestFile.readText()
                        val regex = Regex("""package="([^"]+)"""")
                        val match = regex.find(text)
                        if (match != null) {
                            ns = match.groupValues[1]
                        }
                    }
                    method.invoke(androidExt, ns)
                } catch (e: Exception) {
                }
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
