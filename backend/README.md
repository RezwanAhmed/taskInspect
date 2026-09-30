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
| `gradlew.bat test` | Run the tests (Docker must be running — tests start a real PostgreSQL with Testcontainers) |
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

### First Administrator

On startup, if no administrator exists yet, the backend creates one from
`ADMIN_EMAIL`, `ADMIN_PASSWORD` (at least 12 characters) and
`ADMIN_FULL_NAME`. Passwords are stored only as BCrypt hashes. Once the
administrator exists, these variables are ignored and `ADMIN_PASSWORD`
can be removed.

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

## Local Database (Docker)

The backend connects to PostgreSQL using the `DB_HOST`, `DB_PORT`,
`DB_NAME`, `DB_USERNAME` and `DB_PASSWORD` variables from `.env`. Start
the database before `bootRun`.

PostgreSQL runs in Docker, defined in
[`docker-compose.yml`](../docker-compose.yml) at the repository root.
Requires Docker Desktop.

1. Copy `.env.example` to `.env` and set `DB_PASSWORD`.
2. From the repository root:

| Command | What it does |
|---------|--------------|
| `docker compose up -d` | Start PostgreSQL in the background |
| `docker compose ps` | Show status (`healthy` when ready) |
| `docker compose logs postgres` | Show database logs |
| `docker compose down` | Stop it — data is kept in the `postgres-data` volume |
| `docker compose down -v` | Stop it and **delete** all data |

### Migrations (Flyway)

The database schema is created and changed only by SQL migrations in
`src/main/resources/db/migration`, applied automatically when the
backend starts (Hibernate only validates the schema).

- Add a new file for every change: `V2__create_roles.sql`,
  `V3__...`. Use the next free number and a short description.
- Never edit or delete a migration that has been committed — add a new
  one instead.
- Applied migrations are listed in the `flyway_schema_history` table.

On Windows, if starting fails with *"bind: An attempt was made to access
a socket in a way forbidden"*, the port is reserved by Hyper-V. Set
`DB_PORT` in `.env` to a free port (for example `15432`).
