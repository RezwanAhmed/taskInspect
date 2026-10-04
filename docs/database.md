# TaskInspect — Database

The backend stores everything in **PostgreSQL**
([ADR-0002](decisions/0002-postgresql-as-primary-database.md)); the
mobile app keeps its own **SQLite** database on the device for offline
work ([ADR-0004](decisions/0004-offline-first-mobile-architecture.md)).
Evidence files are not in a database: they are in S3 (or a local folder
in development), the database only keeps their metadata.

## PostgreSQL

### Migrations

- The schema is created and changed only by **Flyway** migrations in
  `backend/src/main/resources/db/migration/` (`V1__baseline.sql` to
  `V20__create_device_tokens.sql` today). They run automatically when
  the backend starts.
- Hibernate never changes the schema (`spring.jpa.hibernate.ddl-auto:
  validate`): it only checks at startup that the entities match it.
- A migration that has run is never edited. A change is a new
  `V<n>__<what>.sql` file. Tests run every migration on a real
  PostgreSQL (Testcontainers), so a broken migration fails the build.

### Conventions

- Primary keys are UUIDs. Objects the app creates offline (tasks,
  requirements, evidence files) get their ID on the device, so the same
  object keeps one ID everywhere.
- `created_at` / `updated_at` (`TIMESTAMPTZ`, UTC) on the main tables;
  tasks also have a `version` for optimistic locking (see
  [api.md](api.md#changes-made-at-the-same-time)).
- Enums are stored as text and guarded by `CHECK` constraints, so the
  database refuses values the code does not know.
- Constraint names say what they are: `pk_`, `fk_`, `uk_` (unique),
  `ck_` (check), `ix_` (index), e.g. `uk_users_email`.
- Deleting a task deletes everything that belongs only to it
  (`ON DELETE CASCADE`): requirements and their options, answers,
  evidence metadata, reviews, status history, assignments, sync
  records.

### Tables

```
organizations ─┬─ users ─┬─ user_roles ── roles
               │         ├─ refresh_tokens
               │         └─ device_tokens
               ├─ tasks ─┬─ task_requirements ─┬─ requirement_options
               │         │                     ├─ task_responses
               │         │                     └─ evidence
               │         ├─ task_assignments
               │         ├─ task_status_history
               │         ├─ task_reviews ── task_review_items
               │         └─ sync_records
               └─ audit_logs
```

Simplified: answers and evidence also point to their task directly
(`task_id`), and a task can point to another task as its main task
(`parent_task_id`) or as the task it was registered again from
(`reissued_from_id`).

| Table | Holds | Notes |
|-------|-------|-------|
| `organizations` | The company the users belong to | One default organization today; every user and task belongs to one |
| `users` | Accounts | `email` unique and lower case; `active` (deactivated users cannot log in); `team_manager_id` = the manager whose team a worker is in (not themself) |
| `roles`, `user_roles` | `ADMINISTRATOR`, `MANAGER`, `WORKER` and who has which | A user can have several roles (e.g. manager and worker) |
| `refresh_tokens` | Refresh tokens, only as SHA-256 hash | `revoked_at`, `replaced_by` (rotation); see [authentication.md](authentication.md) |
| `device_tokens` | Push notification tokens per device | `token` unique (moves to the user who logs in on the device); `platform` `ANDROID` / `IOS` |
| `tasks` | Tasks | `status`, `priority`, `due_date`, `created_by`, `reviewer_id`, `assignee_id`, `version`; `open_scope` (`TEAM` / `EVERYONE`) only while `OPEN`; `parent_task_id` (sub-task of a main task); `reissued_from_id` (registered again) |
| `task_requirements` | The checklist of a task | `type`, `required`, `position` (unique per task), `unit` only for `NUMBER` |
| `requirement_options` | Choices of `DROPDOWN` / `MULTIPLE_SELECTION` | `position` unique per requirement |
| `task_responses` | The worker's answers | One per requirement (`uk_task_responses_requirement`); `boolean_value`, `text_value`, `number_value` (`NUMERIC(19,4)`), `selected_option_ids` (`UUID[]`), `comment` |
| `evidence` | Photos and documents (metadata) | `storage_key` (unique) of the file in S3; `content_type` JPEG / PNG / PDF; `status` `PENDING` until the upload is confirmed, then `UPLOADED` |
| `task_assignments` | Every assignment of a task | Who assigned whom, when |
| `task_status_history` | Every status change | `from_status`, `to_status`, `changed_by`, `reason`; written in the same transaction as the change |
| `task_reviews`, `task_review_items` | Approve / reject / correction request; the requirements marked for correction with their comments | |
| `sync_records` | Operations already applied from the app's sync queue | Lets `POST /api/sync/push` skip an operation sent twice; see [offline-sync.md](offline-sync.md) |
| `audit_logs` | Security-relevant events (logins, failed logins, status changes, ...) | Keeps the entry when the actor is deleted (`actor_id` set to null); `request_id` links to the logs |

### Indexes

Besides the primary and unique keys, indexes cover the columns lists
filter or join on: task `organization_id + status`, `due_date`,
`created_by`, `reviewer_id`, `assignee_id`, `parent_task_id`,
`reissued_from_id`, `created_at`; the `task_id` of every child table;
`users.organization_id` and `team_manager_id`; `audit_logs` by entity,
actor and time.

### Local Development

`docker compose up -d` (repository root) starts PostgreSQL with the
values from `.env` (see `.env.example`). The backend connects with
`DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD` and runs
the migrations on start.

## SQLite on the Device

The app's database (`mobile/lib/core/storage/app_database.dart`, built
with drift) is the source of truth for the screens: everything is read
from it, online or offline, and the sync brings it up to date with the
server.

| Table | Holds |
|-------|-------|
| `LocalTasks`, `LocalRequirements`, `LocalRequirementOptions` | The tasks the user may see, with their checklists |
| `LocalResponses`, `LocalEvidence` | Answers and photo / document files made on the device (the files themselves are in the app's storage) |
| `LocalTaskReviews` | The latest review of each task (e.g. what to correct) |
| `LocalTeamTasks` | Team members' tasks shown as tiles |
| `LocalSyncOperations` | The sync queue: changes not yet sent to the server |
| `LocalSyncState` | Small values the sync keeps between app starts, e.g. the cursor of the last pull |

- Every schema change raises `schemaVersion` (10 today) and adds a
  migration step, because a phone keeps its database between app
  updates. Generated code (`app_database.g.dart`) is committed; after
  changing a table run
  `dart run build_runner build --delete-conflicting-outputs`.
- Signing out deletes the local data (after warning about changes not
  synced yet). When only the session expires, the data stays, marked
  with its owner: the same user gets their unsent changes back after
  signing in again, another account is asked first and never sees them.
- How changes move between the two databases:
  [offline-sync.md](offline-sync.md).
