# ADR-0002: PostgreSQL as Primary Database

- **Status:** Accepted
- **Date:** 2026-09-30

## Context

The backend stores the business data of TaskInspect: users and roles,
tasks, requirements and their options, workers' responses, evidence
metadata, reviews, status history, audit log, refresh tokens and sync
records.

This data is strongly related (a task has requirements, a requirement
has responses and evidence, a task has reviews and history) and must
stay consistent: approving a task, writing its history row and its
audit entry must succeed or fail together. The system also needs
filtering and pagination (by status, assignee, due date), constraints
that protect the data, and a database that runs the same way locally in
Docker, in CI tests and in the cloud.

## Decision

Use **PostgreSQL** as the single primary database for all business
data.

- The schema is managed only by **Flyway** migrations
  (`db/migration/V1__...`); Hibernate validates it
  (`ddl-auto=validate`) and never changes it.
- Tables use **UUID primary keys**, so IDs can also be created on the
  device for offline records and sync operations, and they cannot be
  guessed from the URL.
- Relationships are enforced with foreign keys, `NOT NULL` and check
  constraints; frequently filtered columns (status, assignee, due date)
  are indexed.
- Users and tasks carry an `organization_id` from the start (one
  default organization for now), so organizations can be added later
  without reshaping the data.
- Photos are **not** stored in the database — only their metadata
  (see ADR-0005).

## Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **PostgreSQL** (chosen) | Full ACID transactions; rich constraints; JSON columns when needed; excellent Spring Data JPA and Flyway support; free, open source, and offered by every cloud (e.g. AWS RDS). | Needs to be run and backed up (handled by Docker locally and a managed service in the cloud). |
| MySQL / MariaDB | Also relational and widely hosted. | Fewer advanced features (e.g. weaker check constraints and JSON support in older versions); no advantage for this project. |
| MongoDB (document database) | Flexible schema; easy to store a whole task as one document. | The data is highly relational; multi-document transactions and joins are harder; consistency rules would move into application code. |
| Firebase / Firestore | No server to run; built-in offline sync for mobile. | Business rules (state machine, roles) would be hard to enforce on the server; vendor lock-in; does not show backend skills. |

## Consequences

- A status change, its history row and its audit entry are saved in one
  transaction.
- Every schema change is a reviewed, versioned migration; the same
  migrations run locally, in tests and in production.
- Integration tests run against a real PostgreSQL (Docker /
  Testcontainers) instead of an in-memory substitute, so they match
  production.
- A local PostgreSQL is needed for development — it runs in Docker
  (task 2.4, needs Docker Desktop on the laptop).
