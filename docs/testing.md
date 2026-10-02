# TaskInspect — Testing

What is tested where, how to run it, and the rules every change follows.
Counts are from 2026-10-02: **767 backend tests**, **467 Flutter
tests**, run by GitHub Actions whenever the backend or the app changes.

## Backend

Tests live in `backend/src/test/java/com/taskinspect/`, one package per
feature, like the code.

| Layer | What | Examples |
|-------|------|----------|
| Unit | Services, rules and validators with Mockito, no Spring, no database | `TaskStateMachineTests`, `TaskAssignmentServiceTests`, `ReviewServiceTests`, `ResponseValidationTests`, `AuthServiceTests` |
| Repository | Queries, constraints and cascades on a real PostgreSQL (`@DataJpaTest` + Testcontainers) | `TaskRepositoryTests`, `EvidenceRepositoryTests`, `RefreshTokenRepositoryTests` |
| API / integration | The whole application with MockMvc on a real PostgreSQL: endpoints, rules, history, audit | `AssignTaskTests`, `SubmitTaskTests`, `CorrectionFlowTests`, `SyncPushTests`, `TaskFlowIntegrationTests` |
| Security | Every endpoint as every kind of caller against the documented permissions; invalid tokens | `AuthorizationMatrixTests`, `JwtAuthenticationTests`, `RoleAuthorizationTests` |

- **Real PostgreSQL**: Testcontainers starts `postgres:18-alpine` in
  Docker (`TestcontainersConfiguration`) and every Flyway migration runs,
  so tests see the real schema and constraints. Docker must be running.
- **S3**: `S3FileStorageTests` run against MinIO only with
  `S3_TESTS=true` (skipped by default; 3 tests).
- **Static analysis**: SpotBugs checks the application code as part of
  the build; accepted findings are listed with a reason in
  `backend/config/spotbugs-exclude.xml`.

Run (from `backend/`):

| Command | Does |
|---------|------|
| `./gradlew test` | All tests (Windows: `gradlew.bat test`) |
| `./gradlew test --tests com.taskinspect.reviews.*` | One package |
| `./gradlew test --tests '*ReviewServiceTests'` | One class |
| `./gradlew build` | Compile, all tests, SpotBugs, jar — what CI runs |

Reports: `build/reports/tests/test/index.html` and
`build/reports/spotbugs/main.html`.

## Mobile App

Tests live in `mobile/test/`, mirroring `lib/` (`core/`, `features/<feature>/data|domain|presentation`).

| Layer | What | Examples |
|-------|------|----------|
| Unit | Cubits / BLoCs (`bloc_test`), use cases, repositories, the sync queue and manager, answer rules | `execution_cubit_test`, `auth_bloc_test`, `sync_manager_test`, `answer_test` |
| Data | Local database (drift on an in-memory SQLite) and remote data sources against a fake server | `task_local_data_source_test`, `review_remote_data_source_test` |
| Widget | Screens with the real app router and fakes behind `get_it` | `login_page_test`, `task_list_page_test`, `execution_page_test`, `review_page_test` |
| Scenario | Several parts together, e.g. working offline, then syncing | `core/synchronization/offline_sync_scenario_test` |
| Integration | The real app on a device against a running backend | `integration_test/login_test.dart` |

- **Fakes** for the repositories, sync status, evidence picker and
  server are in `test/helpers/` (`fake_tasks.dart`, `fake_auth.dart`,
  `fake_server.dart`). A change to a shared fake can affect many tests:
  run the whole suite afterwards.
- **Async rules**: a test must be able to fail. For results that arrive
  after a page closed, or races between saving and reading, the fakes
  have optional *gates* (`startGate`, `submitGate`, `saveGate`, the
  picker's `gate`) that hold an answer until the test lets it go; a new
  guard test is checked once by removing the guard and seeing it fail.
- **SQLite**: data tests use drift's native in-memory database; on Linux
  this needs `libsqlite3` (CI installs `libsqlite3-dev`).

Run (from `mobile/`):

| Command | Does |
|---------|------|
| `flutter analyze` | Static analysis (`analysis_options.yaml`) |
| `flutter test` | All unit, widget and scenario tests |
| `flutter test test/features/review` | One folder |
| `flutter test integration_test/login_test.dart -d <device> --dart-define=E2E_EMAIL=... --dart-define=E2E_PASSWORD=...` | Integration test on an emulator or phone with the backend running (skipped without the credentials) |

The integration test of the full worker flow (log in, open a task,
complete it, submit) needs a device and is still open (task 9.6).

## Continuous Integration

GitHub Actions (`.github/workflows/`) on pushes and pull requests to
`main` and `develop`. Backend and Mobile run only when their folder
(`backend/**`, `mobile/**`) or their workflow file changed, CodeQL when
the backend or a workflow changed (and weekly), the secret scan on every
push. Each can also be started by hand (Run workflow).

| Workflow | Runs |
|----------|------|
| Backend | `./gradlew build` (all tests on PostgreSQL in Docker, SpotBugs); then builds the Docker image, scans it for vulnerabilities (Trivy) and starts it against PostgreSQL until `/actuator/health` is up |
| Mobile | `flutter analyze`, `flutter test` |
| CodeQL | Code scanning of the backend and the workflows (also weekly) |
| Secret scan | gitleaks over the whole git history |

A failing workflow uploads its test and SpotBugs reports (Backend).

## Rules for Changes

- Every change comes with tests for its new rules, and its tests run
  before it is pushed.
- A separate review checks each change; the build (`gradlew build`,
  `flutter analyze` + debug APK) must pass.
- The full test suites run before `develop` is merged into `main`.
- Details of the workflow: [CONTRIBUTING.md](../CONTRIBUTING.md).
