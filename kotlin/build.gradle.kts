plugins {
    kotlin("jvm") version "1.9.25"
    `java-library`
    `maven-publish`
    signing
}

// Must match the publication's groupId below and the namespace verified on
// Central — a mismatch here silently produces artifacts under the wrong
// coordinates and Central rejects the bundle.
group = "blog.misar"
version = "1.1.0"

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.1")
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin:2.17.1")
    testImplementation(kotlin("test"))
    // Gradle 9 no longer puts the JUnit Platform launcher on the test runtime
    // classpath implicitly. Without it `gradle test` dies with "Failed to load
    // JUnit Platform" before running a single test.
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")
}

kotlin {
    jvmToolchain(17)
}

tasks.test {
    useJUnitPlatform()
}

java {
    withSourcesJar()
    // Central rejects a release without a javadoc jar.
    withJavadocJar()
}

publishing {
    publications {
        create<MavenPublication>("mavenJava") {
            from(components["java"])
            groupId = "blog.misar"
            artifactId = "misarblog-sdk"

            pom {
                name.set("Misar.Blog Kotlin SDK")
                description.set(
                    "Kotlin client for misar.blog, a hosted blogging platform: publish and schedule " +
                        "Markdown articles, manage drafts and series, read comments, reactions, follows " +
                        "and analytics, generate SEO titles, completions and AI cover images, and search. " +
                        "Coroutine suspend functions; retry with back-off, typed plan-limit errors, " +
                        "iframe embed URLs."
                )
                url.set("https://docs.misar.io/blog/sdks/kotlin")
                licenses {
                    license {
                        name.set("MIT License")
                        url.set("https://opensource.org/licenses/MIT")
                    }
                }
                developers {
                    developer {
                        name.set("Misar AI")
                        email.set("hello@misar.io")
                        organization.set("Misar AI Technology Pvt Ltd")
                        organizationUrl.set("https://misar.io")
                    }
                }
                scm {
                    connection.set("scm:git:https://github.com/Misar-AI/misarblog-sdks.git")
                    developerConnection.set("scm:git:ssh://git@github.com/Misar-AI/misarblog-sdks.git")
                    url.set("https://github.com/Misar-AI/misarblog-sdks")
                }
            }
        }
    }

    repositories {
        maven {
            name = "central"
            url = uri("https://central.sonatype.com/api/v1/publisher/upload")
            credentials {
                username = System.getenv("MAVEN_CENTRAL_USERNAME")
                password = System.getenv("MAVEN_CENTRAL_PASSWORD")
            }
        }
    }
}

signing {
    // Only sign when CI supplies a key, so a local `gradle build` still works
    // without GPG configured.
    val signingKey: String? = System.getenv("GPG_PRIVATE_KEY")
    val signingPassphrase: String? = System.getenv("GPG_PASSPHRASE")
    isRequired = signingKey != null

    if (signingKey != null) {
        useInMemoryPgpKeys(signingKey, signingPassphrase)
        sign(publishing.publications["mavenJava"])
    }
}
