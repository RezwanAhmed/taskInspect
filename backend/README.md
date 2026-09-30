# TaskInspect — Backend

Java / Spring Boot REST API (Spring Security + JWT, Spring Data JPA,
PostgreSQL, OpenAPI). See the
[backend architecture](../docs/architecture.md#backend-architecture) for
the design.

| | |
|---|---|
| Language | Java 25 |
| Framework | Spring Boot 4.1 |
| Build | Gradle (Kotlin DSL) with the Gradle wrapper |
| Base package | `com.taskinspect` |

## Requirements

- JDK 25 (for example Eclipse Temurin). Gradle itself does not need to
  be installed — the wrapper downloads the right version.

## Common Commands

Run from this `backend/` folder (use `gradlew.bat` on Windows,
`./gradlew` on macOS / Linux):

| Command | What it does |
|---------|--------------|
| `gradlew.bat build` | Compile, run all tests and build the jar |
| `gradlew.bat test` | Run the tests |
| `gradlew.bat bootRun` | Start the API on http://localhost:8080 |

## Health Check

Spring Boot Actuator exposes only the health and info endpoints:

| URL | Meaning |
|-----|---------|
| http://localhost:8080/actuator/health | Overall status (`UP` / `DOWN`), no details |
| http://localhost:8080/actuator/health/liveness | The app is running (for container restarts) |
| http://localhost:8080/actuator/health/readiness | The app is ready to receive traffic |

Database, configuration and Docker setup are added in the next Phase 2
tasks.
