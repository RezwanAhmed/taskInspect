# ADR-0004: Offline-first Mobile Architecture

- **Status:** Accepted
- **Date:** 2026-09-30

## Context

Inspections happen in basements, plant rooms, rural sites and moving
vehicles, where the connection is weak or missing. If the app needed
the network for every action, workers would lose answers and photos, or
stop working until they found a signal. The spec makes offline work a
core requirement: the worker must be able to complete and submit a task
offline, and the data must synchronize automatically when the connection
returns — without duplicates.

## Decision

Build the mobile app **offline-first**: the local database on the device
is the source of truth for the UI, and a background **SyncManager**
exchanges changes with the backend.

- Every change the worker makes (start, answer, comment, photo, submit)
  is saved to the local database **and** added to a persistent sync
  queue in one local transaction. The screen updates immediately.
- The SyncManager uploads photos, pushes queued operations in order
  (`POST /api/sync/push`) and pulls server changes
  (`GET /api/sync/pull`), with retries, backoff and a visible status
  (`PENDING`, `SYNCING`, `SYNCED`, `FAILED`).
- Each operation carries a UUID created on the device; the server
  records applied IDs, so resending an operation never creates duplicate
  data (idempotency).
- The server stays the authority: every synced operation passes the same
  state machine, role and ownership checks as a normal API call.
  Conflicts are resolved as described in the offline sync section of
  [architecture.md](../architecture.md#offline-sync).
- Actions that cannot be trusted offline — login, creating and assigning
  tasks, reviewing — stay online-only.

The concrete local database package is chosen in task 4.11; it must
support Android and iOS, transactions and reactive queries (for example
SQLite through `drift`).

## Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **Offline-first with local DB + sync queue** (chosen) | Works with no connection; instant UI; nothing lost when the app is closed; sync is observable and testable. | More code: local schema, queue, retries and conflict handling. |
| Online-only app with a simple cache | Much simpler; no conflicts. | Unusable where inspections actually happen; answers and photos can be lost. |
| Cache failed requests and replay them | Less code than a full sync layer. | No local source of truth; unclear state after restarts; risk of duplicates and out-of-order requests. |
| Backend-as-a-service with built-in offline sync (Firestore, Realm / Atlas Device Sync) | Sync handled by the vendor. | Business rules are hard to enforce on the server; vendor lock-in; Atlas Device Sync has been deprecated; does not show how sync works. |

## Consequences

- Workers can complete and submit whole inspections without a
  connection; the app shows *"Submitted locally — waiting for
  synchronization."* until the server confirms.
- Phase 6 (tasks 6.1-6.14) is dedicated to the sync layer, with its own
  tests for retries, expired logins and conflicts.
- Background sync behaves differently per platform: WorkManager on
  Android, system-limited background tasks on iOS — so the app also
  syncs whenever it is opened.
- The backend needs idempotent sync endpoints and a `sync_records`
  table, and tasks carry a version number for conflict detection.

## Updates

**2026-10-01** — Decisions by the project owner:

- **Creating tasks works offline.** A manager can create and edit draft
  tasks and their requirements without a connection; they are synced as
  `DRAFT` tasks. Login, assigning and reviewing stay online-only.
- **Sync whenever online.** The app tries to sync every time the device
  is online. If sync fails, the data stays in the local database, the
  user is told, and a **Retry** button is shown; automatic retries
  continue while the device is online and never give up on unsent data.
