# Contributing to TaskInspect

How changes are made in this repository. The project is built in small,
numbered tasks; the same rules apply to everyone who works on it (see
"License" at the end: contributions need the owner's permission).

## Getting Started

1. Read the [README](README.md) and [docs/architecture.md](docs/architecture.md).
2. Set up the backend (`backend/README.md`: Java 25, Docker for
   PostgreSQL) and the app (`mobile/README.md`: Flutter stable).
3. Copy `.env.example` to `.env` and fill in the values. Never commit
   `.env` or any secret — CI scans the whole git history for secrets.

## Branches

| Branch | Purpose |
|--------|---------|
| `develop` | All work. Every change is pushed here. |
| `main` | Released state. Updated only by a pull request from `develop` at the end of a phase, after the full test suites pass. Never pushed to directly. |

## One Small Change at a Time

- Work on one task at a time, roughly one commit each. If a task grows,
  split it into smaller ones (e.g. 9.4 → 9.4a, 9.4b) and do them one by
  one.
- A commit contains one focused change and its tests — no unrelated
  edits, no reformatting of untouched code.

## Commit Messages

```
<type>: <short summary>

<body: what changed and why>
```

- Subject: imperative, lower case, no trailing period, at most about
  72 characters, e.g. `feat: add task state machine`.
- Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`,
  `build`, `style`, `perf`.
- Body wrapped at about 72 characters: what changed (main files or
  classes), why, decisions taken, and how it was verified (which tests
  ran, results).
- The template is in `.gitmessage`:
  `git config commit.template .gitmessage`.

## Code Style

- `.editorconfig`: UTF-8, LF line endings (CRLF only for `.bat`, `.cmd`,
  `.ps1`), 2 spaces, 4 for Java / Kotlin / Gradle; `.gitattributes`
  keeps the line endings in git.
- **Match the surrounding code** — its naming, comment density and
  layout. Comments explain *why*, not *what*.
- **Flutter**: do not run `dart format` on folders. The code is
  formatted by hand (lines up to about 120 characters), so the formatter
  would rewrite many unrelated files. `flutter analyze` must report no
  issues.
- **Java**: SpotBugs runs in the build; a finding fails it. Accept a
  finding only with a reason in `backend/config/spotbugs-exclude.xml`.
- Clean Architecture in the app (`presentation` → `domain` ← `data`),
  one package per feature in the backend
  ([architecture.md](docs/architecture.md)).

## Tests and Checks

Before a change is pushed:

- New rules come with tests; the tests of the changed code run and
  pass. A test must be able to fail — see
  [docs/testing.md](docs/testing.md).
- The build passes: `./gradlew build` for the backend, `flutter
  analyze` (and a debug APK build) for the app.
- After changing a shared test helper (`mobile/test/helpers/`, backend
  test fixtures), run the whole suite.
- A second person (or a separate review step) reviews the change for
  bugs, missed cases and fit with the architecture; findings are fixed
  before the push.

GitHub Actions then runs the backend build and tests, the Docker image
build and vulnerability scan, the Flutter analysis and tests, CodeQL and
the secret scan on every push to `develop` and every pull request. A red
workflow is fixed first.

## Documentation

- Behaviour that clients or other developers rely on is documented in
  `docs/` (API, database, authentication, offline sync, testing) and
  updated in the same change that alters it.
- Larger technical decisions get an Architecture Decision Record in
  `docs/decisions/` (copy `0000-template.md`).

## Platforms

The app is released on Google Play first and on the App Store later.
Use Flutter packages that support Android **and** iOS, and when adding
anything platform-specific (permissions, notifications, background
work, file storage) note what iOS needs.

## License

TaskInspect is not open source: the code is public to be viewed, all
rights are reserved (see [LICENSE](LICENSE)). Changes are made only by
the owner or by people working on it with the owner's written
permission.
