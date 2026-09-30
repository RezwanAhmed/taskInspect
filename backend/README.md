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

## Configuration

All settings that differ between environments come from environment
variables — nothing secret is committed.

1. Copy [`.env.example`](../.env.example) (repository root) to `.env`
   and adjust the values. `.env` is ignored by git.
2. When the backend starts, it reads `.env` from the repository root or
   from `backend/` if one exists. Real environment variables (Docker,
   CI, cloud) always take priority over `.env`.

Profiles select environment-specific settings:

| Profile | File | Used for |
|---------|------|----------|
| `dev` (default) | `application-dev.yml` | Local development — debug logging for `com.taskinspect` |
| `prod` | `application-prod.yml` | Production — quiet logs, no error details or stack traces sent to clients |

Set the profile with `SPRING_PROFILES_ACTIVE` (for example
`SPRING_PROFILES_ACTIVE=prod`). Shared settings live in
`application.yml`.

## Health Check

Spring Boot Actuator exposes only the health and info endpoints:

| URL | Meaning |
|-----|---------|
| http://localhost:8080/actuator/health | Overall status (`UP` / `DOWN`), no details |
| http://localhost:8080/actuator/health/liveness | The app is running (for container restarts) |
| http://localhost:8080/actuator/health/readiness | The app is ready to receive traffic |

## API Documentation

With the `dev` profile, the API is described with OpenAPI (springdoc):

| URL | What it shows |
|-----|---------------|
| http://localhost:8080/swagger-ui.html | Swagger UI — browse and try the endpoints |
| http://localhost:8080/v3/api-docs | The OpenAPI description as JSON |

Both are turned off with the `prod` profile.

Database and Docker setup are added in the next Phase 2 tasks.
