import com.vanniktech.maven.publish.SonatypeHost

plugins {
    kotlin("jvm") version "1.9.25"
    `java-library`
    // NOT `maven-publish` + `signing`. Those upload by PUTting each file to the
    // repository URL, but https://central.sonatype.com/api/v1/publisher/upload is
    // a bundle POST API, not a Maven repo — every PUT 404s and nothing is ever
    // published. This plugin speaks the Central Portal protocol.
    id("com.vanniktech.maven.publish") version "0.30.0"
}

// Must match the publication's groupId below and the namespace verified on
// Central — a mismatch here silently produces artifacts under the wrong
// coordinates and Central rejects the bundle.
group = "blog.misar"
version = "5.0.3"

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

// The sources and javadoc jars Central requires are produced by the publishing
// plugin's KotlinJvm configuration below, so declaring them here too would make
// Gradle build two artifacts for the same classifier.

mavenPublishing {
    publishToMavenCentral(SonatypeHost.CENTRAL_PORTAL, automaticRelease = true)
    signAllPublications()
    // Was "misarblog-sdk", which matched neither sibling. Nothing was ever
    // published under it, so there is no one to break by making the three
    // consistent: misarblog-kotlin / misarmail-kotlin / misarreach-kotlin.
    coordinates("blog.misar", "misarblog-kotlin", version.toString())

    pom {
        name.set("Misar.Blog Kotlin SDK")
        description.set(
            "Kotlin client for misar.blog, a hosted blogging platform: publish and schedule " +
                "Markdown articles, manage drafts and series, read comments, reactions, follows " +
                "and analytics, generate SEO titles, completions and AI cover images, and search. " +
                "Coroutine suspend functions; retry with back-off, typed plan-limit errors, " +
                "iframe embed URLs."
        )
        url.set("https://www.misar.blog")
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
        issueManagement {
            system.set("GitHub Issues")
            url.set("https://github.com/Misar-AI/misarblog-sdks/issues")
        }
    }
}
