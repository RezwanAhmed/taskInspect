plugins {
    java
    id("org.springframework.boot") version "4.1.1"
    id("io.spring.dependency-management") version "1.1.7"
    id("com.github.spotbugs") version "6.5.12"
}

group = "com.taskinspect"
version = "0.0.1-SNAPSHOT"
description = "TaskInspect REST API"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(25)
    }
}

repositories {
    mavenCentral()
}

// Security fixes newer than Spring Boot 4.1.1 manages (found by the image
// scan, task 10.5a). Remove each line once a Spring Boot update includes
// the version or a newer one.
extra["tomcat.version"] = "11.0.25"        // CVE-2026-65182, -65905, -68525 (critical)
extra["jackson-bom.version"] = "3.1.7"     // CVE-2026-68497, -89407, -89425, -91776, -91777
extra["jackson-2-bom.version"] = "2.21.7"  // the same CVEs in Jackson 2

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-flyway")
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("org.springframework.boot:spring-boot-starter-security-oauth2-resource-server")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-webmvc")
    implementation("org.flywaydb:flyway-database-postgresql")
    implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:3.1.1")
    implementation(platform("software.amazon.awssdk:bom:2.55.10"))
    implementation("software.amazon.awssdk:s3")
    runtimeOnly("org.postgresql:postgresql")
    testImplementation("org.springframework.boot:spring-boot-starter-data-jpa-test")
    testImplementation("org.springframework.boot:spring-boot-starter-flyway-test")
    testImplementation("org.springframework.boot:spring-boot-starter-security-oauth2-resource-server-test")
    testImplementation("org.springframework.boot:spring-boot-starter-security-test")
    testImplementation("org.springframework.boot:spring-boot-starter-webmvc-test")
    testImplementation("org.springframework.boot:spring-boot-testcontainers")
    testImplementation("org.testcontainers:testcontainers-junit-jupiter")
    testImplementation("org.testcontainers:testcontainers-postgresql")
    testImplementation("org.testcontainers:testcontainers-minio")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

// Only the executable Spring Boot jar is built (the Docker image copies it).
tasks.jar {
    enabled = false
}

tasks.withType<Test> {
    useJUnitPlatform()
}

// Static analysis of the application code (task 10.2); part of `check`, so
// `gradlew build` fails on a finding. Known false positives are listed,
// with the reason, in config/spotbugs-exclude.xml.
spotbugs {
    toolVersion = "4.10.4"
    excludeFilter = file("config/spotbugs-exclude.xml")
}

tasks.spotbugsMain {
    reports.create("html") { required = true }
}

// Tests are not analysed: mocks and fixtures trigger patterns on purpose.
tasks.spotbugsTest {
    enabled = false
}
