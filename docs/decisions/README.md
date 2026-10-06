# Architecture Decision Records

An Architecture Decision Record (ADR) explains one important technical
choice: the situation, what was decided, which options were considered
and what the decision costs. ADRs are short and are never rewritten
after they are accepted. Small changes that keep the decision are added
at the end under *Updates*, with a date; if the decision itself changes,
a new ADR replaces the old one and the old one is marked *Superseded*.

## Index

| ADR | Title | Status |
|-----|-------|--------|
| [0001](0001-flutter-for-cross-platform-mobile.md) | Flutter for cross-platform mobile | Accepted |
| [0002](0002-postgresql-as-primary-database.md) | PostgreSQL as primary database | Accepted |
| [0003](0003-jwt-authentication.md) | JWT authentication | Accepted |
| [0004](0004-offline-first-mobile-architecture.md) | Offline-first mobile architecture | Accepted |
| [0005](0005-s3-for-evidence-storage.md) | S3 for evidence storage | Accepted |
| [0006](0006-free-tier-providers-for-initial-deployment.md) | Free-tier providers for initial deployment | Accepted |

## Writing a New ADR

1. Copy [`0000-template.md`](0000-template.md) to
   `NNNN-short-title.md`, using the next free number.
2. Fill in every section and set the status to *Proposed*.
3. Change the status to *Accepted* once the decision is agreed, and add
   the ADR to the index above.
