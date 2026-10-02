# TaskInspect — Architecture

This document describes how TaskInspect is put together: the main
components, what each one is responsible for, and how they talk to each
other.

## System Overview

TaskInspect has three parts:

- **Mobile app (Flutter)** — used by workers to execute tasks and by
  managers to create, assign and review them. The app is offline-first:
  tasks, answers and evidence files are stored in a local database on the device,
  and a sync manager exchanges changes with the backend whenever a
  connection is available.
- **Backend API (Spring Boot)** — a stateless REST API that owns the
  business rules. It authenticates users with JWT, checks each user's role,
  enforces the task state machine and records every status change and
  important action. The mobile app never writes to the database or
  storage directly — it goes through the API.
- **Data and cloud services** — PostgreSQL is the source of truth for all
  business data. Evidence files (photos and PDFs) go to AWS S3; the
  database keeps only their metadata. Firebase Cloud Messaging delivers
  push notifications, and CloudWatch collects backend logs.

Everything is kept deliberately small: one backend service, one database
and a few managed cloud services, so that the whole system can be
understood and run locally with `docker compose up`.

## Component Diagram

```mermaid
flowchart LR
    subgraph Device["Mobile device — Flutter app"]
        UI["UI<br/>(screens + BLoC)"]
        Sync["Sync manager<br/>(background)"]
        Local[("Local database<br/>+ evidence files")]
        UI --> Local
        Sync --> Local
    end

    subgraph Backend["Backend — Docker"]
        API["Spring Boot REST API<br/>Security + JWT, services, JPA"]
        Notify["Notification<br/>service"]
    end

    PG[("PostgreSQL<br/>business data")]
    Redis[("Redis<br/>cache, optional")]
    S3[("AWS S3<br/>evidence files")]
    FCM["Firebase Cloud<br/>Messaging"]
    CW["AWS CloudWatch<br/>logs"]

    UI -->|"REST + JWT"| API
    Sync -->|"REST + JWT<br/>push / pull"| API
    Sync -->|"upload files<br/>(pre-signed URL)"| S3
    API --> PG
    API -.-> Redis
    API -->|"pre-signed URLs"| S3
    API -.->|logs| CW
    API --> Notify
    Notify --> FCM
    UI <-.->|"push notifications"| FCM
```

Solid lines are the main request and data paths. Dotted lines are
supporting paths: the optional Redis cache, logging, and push
notifications (the app registers its device with FCM and receives
notifications from it).

## Components

| Component | Responsibility |
|-----------|----------------|
| Flutter UI | Screens for login, dashboard, task list, requirement execution and review. State is managed with BLoC; the UI reads and writes the local database, so it works the same online and offline. |
| Local database | Stores tasks, requirements, answers and the sync queue on the device. It is the source of truth for the UI while offline. |
| Local evidence files | Compressed photos and attached PDF documents waiting to be uploaded, referenced from the local database. |
| Sync manager | Pushes queued local changes to the backend, pulls server changes, uploads evidence files and retries failed operations with backoff. Runs in the background. |
| Spring Boot REST API | Authentication (JWT access + refresh tokens), role-based authorization, task and requirement management, the task state machine, review, audit log and the sync endpoints. Documented with OpenAPI / Swagger. |
| Notification service | Sends notifications for assignment, submission and review results through FCM to the users' registered devices. |
| PostgreSQL | Users, roles, tasks, requirements, responses, reviews, status history, audit log and evidence metadata. Schema managed with Flyway migrations. |
| Redis | Optional cache / short-lived data where it clearly helps; the system works without it. |
| AWS S3 | Stores evidence files (photos and PDF documents). The backend issues a pre-signed upload URL, the app uploads the file directly, and the backend stores the file's metadata (task, requirement, storage key, type, size). |
| Firebase Cloud Messaging | Delivers push notifications to the mobile app (foreground, background and tap to open the task). |
| AWS CloudWatch | Central backend logs, together with Spring Boot Actuator health checks. |

## Key Design Principles

- **The backend enforces the rules.** Roles, allowed state changes and
  ownership are checked on the server, not only in the app.
- **Offline-first mobile.** The app never blocks the user on the network;
  changes are saved locally first and synchronized later.
- **Idempotent synchronization.** Every queued operation has an ID, so
  sending the same request twice never creates duplicate data.
- **Files outside the database.** Photos and PDFs live in object storage; the
  database stores only metadata.
- **Stateless API.** Authentication uses JWT, so the backend can be
  restarted or scaled without losing sessions.

## Task Lifecycle

Every task moves through a fixed set of states. The backend owns this
state machine: each action is a separate API call, and the server checks
that the change is allowed from the current state and by the current user
before applying it. The mobile app only offers the actions that are valid,
but it is never trusted to decide.

```mermaid
stateDiagram-v2
    direction LR
    [*] --> DRAFT: create
    DRAFT --> ASSIGNED: assign
    DRAFT --> OPEN: publish
    OPEN --> ASSIGNED: take
    ASSIGNED --> IN_PROGRESS: start
    IN_PROGRESS --> SUBMITTED: submit
    SUBMITTED --> APPROVED: approve
    SUBMITTED --> REJECTED: reject
    SUBMITTED --> CORRECTION_REQUESTED: request<br/>correction
    REJECTED --> IN_PROGRESS: start again
    CORRECTION_REQUESTED --> IN_PROGRESS: start correction
    APPROVED --> [*]

    DRAFT --> CANCELLED: cancel
    OPEN --> CANCELLED: cancel
    ASSIGNED --> CANCELLED: cancel
    IN_PROGRESS --> CANCELLED: cancel
    REJECTED --> CANCELLED: cancel
    CORRECTION_REQUESTED --> CANCELLED: cancel
    CANCELLED --> [*]
```

### States

| State | Meaning |
|-------|---------|
| `DRAFT` | Created by a manager; title, details and requirements are still being defined. Not visible to workers. |
| `OPEN` | Published without an assignee, for a team (or every worker) to take (Phase 7A, see *Open Tasks*). |
| `ASSIGNED` | Assigned to a worker, who has not started it yet (shown as *pending* in the app). |
| `IN_PROGRESS` | The worker is completing the requirements and attaching evidence. |
| `SUBMITTED` | The worker has submitted the task; it is waiting for review. |
| `REJECTED` | The reviewer rejected the whole task, with a reason. It is back with the worker, who can change any answer or photo. |
| `CORRECTION_REQUESTED` | The reviewer marked only some requirements as needing a fix, each with a comment. It is back with the worker, who can change only the marked requirements. |
| `APPROVED` | The reviewer accepted the task. Final — it can no longer be changed. |
| `CANCELLED` | A manager cancelled the task. Final. |

### Transitions

| From | To | Action | Who | Conditions |
|------|----|--------|-----|------------|
| — | `DRAFT` | Create (`POST /api/tasks`) | Manager, or administrator (main task) | Title, priority and due date are valid. A reviewer is set (defaults to the creator); for a main task it is an administrator. |
| `DRAFT` | `ASSIGNED` | Assign (`POST /api/tasks/{id}/assign`) | Manager, or administrator (main task) | The task has at least one requirement; the assignee is an active worker. A main task goes to an active manager and needs no requirement. |
| `DRAFT` | `OPEN` | Publish (`POST /api/tasks/{id}/publish`) | Manager | The task has at least one requirement; who may take it: team (needs an active team member, else `409 TEAM_HAS_NO_MEMBERS`) or everyone. |
| `OPEN` | `ASSIGNED` | Take (`POST /api/tasks/{id}/take`) | A worker who may take it | The first one wins (`409 TASK_ALREADY_TAKEN` for the others). |
| `ASSIGNED` | `IN_PROGRESS` | Start (`POST /api/tasks/{id}/start`) | Assigned worker | — |
| `IN_PROGRESS` | `SUBMITTED` | Submit (`POST /api/tasks/{id}/submit`) | Assigned worker | Every required requirement has a response. |
| `SUBMITTED` | `APPROVED` | Approve | Task's reviewer | The reviewer is not the assignee (except solo accounts). |
| `SUBMITTED` | `REJECTED` | Reject | Task's reviewer | A reason is given; the reviewer is not the assignee (except solo accounts). |
| `SUBMITTED` | `CORRECTION_REQUESTED` | Request correction | Task's reviewer | At least one requirement is marked, each with a comment; the reviewer is not the assignee (except solo accounts). |
| `REJECTED` | `IN_PROGRESS` | Start again (`POST /api/tasks/{id}/start`) | Assigned worker | — |
| `CORRECTION_REQUESTED` | `IN_PROGRESS` | Start correction (`POST /api/tasks/{id}/start`) | Assigned worker | — |
| `DRAFT`, `OPEN`, `ASSIGNED`, `IN_PROGRESS`, `REJECTED`, `CORRECTION_REQUESTED` | `CANCELLED` | Cancel | Manager | — |

*Reject* and *request correction* are two different results:

- **Reject** sends the whole task back. The worker can change every
  answer and photo before submitting again.
- **Request correction** sends back only the requirements the reviewer
  marked (for example *"Please retake the refrigerator photo."*). The
  worker can change only those; all other answers stay as submitted.

Either way the review record stores the result, the reason and the
marked requirements, and the worker is notified.

### Reviewers and Account Types

Every task has its own **reviewer**, chosen when the task is created or
assigned. The reviewer can be a different manager from the one who
created and assigned the task — for example one manager assigns the
work and another reviews and closes it.

TaskInspect is meant for three sizes of account:

| Account | Example | Review rule |
|---------|---------|-------------|
| Solo | One person using tasks as a personal checklist | The same person creates, does and approves the task (self-review is allowed). |
| Small team | One manager with about 10 workers | The reviewer is never the assigned worker. |
| Organization | Many managers, each with their own workers | The reviewer is never the assigned worker; any manager can be a task's reviewer. |

The first release has one default organization; users and tasks already
carry an `organization_id` so that full organizations (sign-up, several
organizations, managers with their own workers) can be added later
without reshaping the data.

### Rules

- **Invalid changes are rejected.** Any action that is not in the table —
  for example approving a task that is still `IN_PROGRESS` — returns
  `409 Conflict` with the error code `TASK_INVALID_TRANSITION`. Acting on a
  final task returns a specific code such as `TASK_ALREADY_APPROVED`.
- **Roles are checked on every call.** A worker can never approve or
  reject a task — including their own — even with a hand-crafted request.
  Only the task's reviewer can review it; in a solo account that is the
  same person, who holds both the manager and worker roles.
- **Responses are editable only while the task is `IN_PROGRESS`.** Once a
  task is submitted, the worker's answers and evidence are locked. After a
  *reject* they are all editable again; after a *request correction* only
  the marked requirements are.
- **Final states are final.** `APPROVED` and `CANCELLED` tasks cannot be
  modified.
- **Every change is recorded.** Each transition writes a row to the task's
  status history (old state, new state, user, time, reason) and an entry
  in the audit log. These rows build the task history timeline (created,
  assigned, started, submitted, rejected, correction requested,
  resubmitted, approved).
- **Changes trigger notifications.** Assigning, submitting, approving,
  rejecting and requesting a correction notify the other party through
  push notifications.
- **Offline actions are applied when they reach the server.** A worker can
  start and submit a task offline; the app shows it as *submitted locally*
  and the state machine checks the action when it is synchronized (see
  the offline sync section).

## Teams, Open Tasks and Sub-tasks

Decided by Rezwan on 2026-10-01; built in Phase 7A. These rules extend
the task lifecycle above; everything else stays as described there.

### Teams

- Every worker belongs to **one** manager's team. An administrator sets
  a worker's team (and can move them to another team). A worker without
  a team sees only the tasks assigned to them.
- A manager leads one team. Managers and administrators keep seeing all
  tasks of their organization, as before.

### What a Worker Sees

| Tasks | What the worker sees |
|-------|----------------------|
| Assigned to them | Everything (requirements, their answers and evidence) — as before |
| Of their own team (assigned to a team member) | A **tile**: title, status, priority, due date and who it is assigned to — no requirements, answers or evidence |
| Open tasks they may take (see below) | Everything, so they can decide to take it |
| Of other teams | Only numbers per manager: how many tasks, how many team members |

The server enforces this on every call, including the sync pull: a tile
is sent without requirements, and other teams only as counts. In the
app, the **Teams** page (from the dashboard) shows every manager's team
in numbers: members and open tasks, the user's own team marked. It is
loaded online (`GET /api/teams`), not stored on the device.

### Open Tasks

A manager can publish a task **without an assignee**, for a team to pick
up. A worker takes it, and from then on it is their task.

```mermaid
stateDiagram-v2
    direction LR
    DRAFT --> OPEN: publish<br/>(team or everyone)
    OPEN --> ASSIGNED: take<br/>(first worker wins)
    OPEN --> CANCELLED: cancel
    ASSIGNED --> IN_PROGRESS: start
```

- When publishing, the manager chooses who may take it: **their team
  only** or **every worker** of the organization (per task).
- The first worker who takes it gets it; a second one gets
  `409 TASK_ALREADY_TAKEN`. Taking needs a connection (like assigning).
- The task's reviewer stays the one the manager chose.
- A worker sees the open tasks they may take in the task list, the
  details and the sync pull. Open to the team means: the team of the
  manager who published it, while that manager is active. Once taken,
  the task leaves the other workers' lists (`404` for them).

### Tasks for Managers and Sub-tasks

An administrator can create a task and assign it to a **manager** (the
main task). The manager keeps the main task and:

- for a one-person job, creates **one sub-task** for a worker of their
  team (the work is passed on);
- for a big job, splits it into **several sub-tasks**, each assigned to
  a worker (or published as an open task).

Sub-tasks are normal tasks with a link to their main task: the manager
reviews them. The main task's progress shows how many sub-tasks are
approved; when all of them are, the manager submits the main task and
the administrator reviews it.

This widens three rules of the lifecycle tables for main tasks only:
an administrator may **create** a task, **assign** it to a manager, and
the assigned manager **starts** and **submits** it (the worker-only
rules stay for every other task). A main task has no answers of its
own: it is complete when all its sub-tasks are approved.

The manager adds sub-tasks with `POST /api/tasks/{id}/sub-tasks` (same
body as creating a task). A sub-task starts as `DRAFT`, is created by
the manager (who reviews it by default) and carries `parentTaskId`;
the manager then assigns it to a worker or publishes it, as any task.
Workers see only their sub-task, never the main task.

The main task's progress is the number of approved sub-tasks out of
those not cancelled (the app counts them from
`GET /api/tasks/{id}/sub-tasks`). The manager starts the main task and
submits it once every sub-task that is not cancelled is approved; the
administrator then approves or rejects it. After a reject the manager
starts it again and can add sub-tasks. (A correction request needs
marked requirements, so it does not apply to a main task.)

A task an administrator creates is a main task: its reviewer is an
administrator (by default the creator), it is assigned to an active
manager without requirements, and it cannot be published as an open
task (`409 MAIN_TASK_NOT_PUBLISHABLE`).

### Registering a Task Again

Once work has started a task can no longer be edited. If the manager
needs a change:

- that the worker can fix in the same task — they **request a
  correction** (review flow above);
- that is a new piece of work — they **register a new task for the same
  worker** from the existing one (its details and requirements are
  copied and can be changed). Both tasks stay with the worker; the new
  one links to the one it was made from.

A correction can only be requested while the task is `SUBMITTED`. A task
can be registered again once work has started (`IN_PROGRESS` or later,
including `APPROVED`); the new one starts as `ASSIGNED` to the same
worker, so the manager can still edit it before the worker starts.

The manager who created the task registers it again with
`POST /api/tasks/{id}/reissue` (`409 TASK_NOT_REISSUABLE` before work
has started, for a cancelled task and for a main task). The new task
copies the title, description, priority, due date and requirements,
carries `reissuedFromId`, and is assigned to the same worker (who must
still be active). The reviewer stays, unless they were deactivated:
then the manager reviews it. The original task is not changed.

### The Worker's Tabs

| Tab | Shows |
|-----|-------|
| **My tasks** — Pending | Assigned to me, not started |
| **My tasks** — Rejected | Mine, rejected or with a correction request |
| **My tasks** — Partially done | Mine, in progress |
| **My tasks** — Done | Mine, submitted or approved (read-only) |
| **All tasks** — Open tasks | Open tasks I may take |
| **All tasks** — Team: pending | My team's tasks that are not done yet: assigned, in progress, submitted (tiles) |
| **All tasks** — Team: rejected | My team's rejected tasks, also with a correction request (tiles) |

Managers keep the dashboard and task list they have now (they see every
task of their organization).

### Data Changes

| Table | New column | Meaning |
|-------|------------|---------|
| `users` | `team_manager_id` | The manager whose team the worker is in (null: no team) |
| `tasks` | `open_scope` | `TEAM` or `EVERYONE` while the task is `OPEN`, otherwise null |
| `tasks` | `parent_task_id` | The main task of a sub-task |
| `tasks` | `reissued_from_id` | The task a re-registered task was made from |

New state `OPEN`; new actions *publish* and *take* in the state machine.

On the phone, tiles are stored in their own table (`local_team_tasks`,
no requirements, answers or evidence), apart from the full tasks, so a
tile is never shown or synced as one of the user's own tasks. The sync pull
follows the new visibility: tasks the worker may no longer see (e.g. an
open task someone else took) leave `taskIds` and are removed. A team
change makes the next pull a full one (the server tells the app with a
team version in the pull), because a change cursor can't show tasks that
became visible without changing themselves. In the pull, tiles come apart from
the full tasks: `tileIds` (every tile the user may see now) and `tiles`
(the changed ones, without requirements), so an app that doesn't know
tiles yet never stores them as tasks. `teamVersion` changes when the
user joins or leaves a team, a member joins or leaves it, or its manager
is deactivated; it is `none` without a team. Other teams' numbers are
not in the pull (`GET /api/teams`, online). Publishing and taking need a
connection (see *What Works Offline*). The API permissions table below
changes with tasks 7A.3-7A.7.

| Part | Tasks |
|------|-------|
| This design | 7A.1 |
| Teams, visibility | 7A.3-7A.4 |
| Open tasks | 7A.5 |
| Tasks for managers, sub-tasks | 7A.6 |
| Registering a task again | 7A.7 |
| Sync pull with the new visibility | 7A.8 |
| App: tabs, other teams' numbers, manager screens | 7A.9-7A.12 |

## Mobile Architecture

The Flutter app follows **feature-based Clean Architecture** with
**BLoC** for state management. Each feature (authentication, tasks,
requirements, evidence, review, ...) is split into the same three layers,
and dependencies always point inwards: the UI knows about the domain, the
data layer implements the domain, and the domain knows about neither.

```mermaid
flowchart TB
    subgraph Presentation["Presentation"]
        W["Screens + widgets"]
        B["BLoC<br/>(events in, states out)"]
    end

    subgraph Domain["Domain — pure Dart"]
        UC["Use cases"]
        RI["Repository interfaces<br/>+ entities"]
    end

    subgraph Data["Data"]
        R["Repository implementations"]
        Remote["Remote data source<br/>(Dio API client)"]
        LocalDS["Local data source<br/>(database + files)"]
    end

    API["Backend REST API"]
    DB[("Local database<br/>+ evidence files")]

    W -->|"events"| B
    B -->|"calls"| UC
    UC -->|"uses"| RI
    RI -->|"implemented by"| R
    R --> Remote
    R --> LocalDS
    Remote -->|"HTTPS + JWT"| API
    LocalDS --> DB
```

Arrows show how a call travels. The code dependencies point the other
way where it matters: repository implementations in the data layer
depend on the interfaces defined in the domain, so the domain never
imports anything from the data layer.

### Layers

| Layer | Folder | Contains | Depends on |
|-------|--------|----------|------------|
| Presentation | `features/<feature>/presentation/` | Screens, widgets and BLoCs. Widgets send events to a BLoC and rebuild from the states it emits. | Domain |
| Domain | `features/<feature>/domain/` | Entities (e.g. `Task`, `Requirement`, `Response`), repository interfaces and use cases (e.g. `StartTask`, `SaveResponse`, `SubmitTask`). Plain Dart — no Flutter, HTTP or database code. | Nothing |
| Data | `features/<feature>/data/` | Models (JSON and database mapping), remote data sources (API calls), local data sources (database queries) and the repository implementations that combine them. | Domain |

Shared building blocks live outside the features: `core/` holds
infrastructure used by every feature (API client, local database, secure
storage, synchronization, error types, theme, router, dependency
injection), and `shared/` holds reusable widgets, models and extensions.

### Folder Structure

```text
mobile/lib/
├── core/
│   ├── constants/
│   ├── error/            # exceptions, failures, error-to-message mapping
│   ├── network/          # Dio client, auth + token refresh interceptor
│   ├── storage/          # local database, file storage
│   ├── security/         # secure token storage
│   ├── synchronization/  # sync queue + SyncManager
│   ├── utils/
│   ├── theme/            # Material 3, light + dark
│   └── router/
├── features/
│   ├── authentication/   # each feature: data/ domain/ presentation/
│   ├── dashboard/
│   ├── tasks/
│   ├── requirements/
│   ├── evidence/
│   ├── review/
│   └── profile/
├── shared/
│   ├── widgets/
│   ├── models/
│   └── extensions/
└── main.dart
```

### Data Flow: Answering a Requirement

The local database is the app's source of truth. Screens read from it
and every change is written there first, so the app behaves the same
online and offline:

1. The worker answers "Is the gas connection safe?" with *Yes*. The
   widget sends a `ResponseChanged` event to the execution BLoC.
2. The BLoC calls the `SaveResponse` use case.
3. The repository writes the response to the local database with
   `syncStatus = PENDING` and adds an operation to the sync queue — in
   one transaction.
4. The local database notifies its watchers; the BLoC emits a new state
   and the screen shows the answer immediately, without waiting for the
   network.
5. Later, the SyncManager sends the queued operation to the backend and
   marks the record `SYNCED` (see the offline sync section).

Actions that only make sense online — logging in, or a manager
assigning or reviewing tasks — go straight to the API through the remote
data source, and the result is then stored locally.

### State Management (BLoC)

- One BLoC (or Cubit for simple screens) per screen or flow, e.g.
  `AuthBloc`, `TaskListBloc`, `TaskExecutionBloc`, `ReviewBloc`.
- BLoCs only talk to use cases, never to Dio or the database directly.
- States cover every case the UI must show: loading, success, empty,
  offline, syncing, sync failed, unauthorized, server error and no
  internet.
- An app-wide `AuthBloc` tracks the session; when the token can no longer
  be refreshed it logs the user out and the router returns to login.

### Error Handling

The data layer catches exceptions (network, server, database) and turns
them into typed failures — for example `NetworkFailure`,
`UnauthorizedFailure` or `ServerFailure(code)` using the backend's error
code. Use cases return either a result or a failure, and the presentation
layer maps each failure to a user-friendly message, such as *"Changes
saved locally. They will sync when you're online."*

### Testability

Because each layer depends only on interfaces, it can be tested on its
own: use cases and BLoCs with mocked repositories, repositories with
mocked data sources, and screens with widget tests. Dependencies are
wired in one place with dependency injection, so tests can swap in fakes.

## Backend Architecture

The backend is a single Spring Boot application (a modular monolith). It
is organised **by feature**: each module owns its controllers, services,
repositories, entities and DTOs, and inside every module the code follows
the same layers.

### Layers

| Layer | Contains | Responsibility |
|-------|----------|----------------|
| Controller | `@RestController` classes, request / response DTOs | HTTP only: validate the request body, check the caller's role, call a service, return a DTO. No business logic. |
| Service | `@Service` classes | Business rules and transactions: the task state machine, ownership checks ("is this the assigned worker?"), writing status history and audit entries. |
| Repository | Spring Data JPA interfaces | Database access for the module's entities. |
| Domain | JPA entities, enums (`TaskStatus`, `RequirementType`) | The data model. Entities are never returned from the API; controllers map them to DTOs. |

Larger modules such as tasks can later grow into a richer structure
(application service → domain → repository interface → infrastructure);
the module boundary stays the same.

### Modules

| Module | Responsibility | Built in |
|--------|----------------|----------|
| `auth` | Login, JWT access tokens, refresh tokens, logout | 2.12-2.19 |
| `users` | Users and roles (administrator, manager, worker) | 2.9-2.11, 2.20 |
| `tasks` | Tasks, assignment, state machine, status history | 3.1-3.6, 3.9-3.10, 3.12 |
| `requirements` | Requirements and their options | 3.7-3.8 |
| `responses` | Workers' answers to requirements | 3.11 |
| `reviews` | Submit, approve, reject, request correction, resubmit | 7.1-7.4 |
| `evidence` | Evidence metadata and upload flow | 5.17, 8.2 |
| `filestorage` | Wrapper around S3 (pre-signed URLs), replaceable in tests | 8.1-8.2 |
| `sync` | Idempotent push / pull endpoints for the mobile app | 6.4, 6.6 |
| `notifications` | Device tokens and push notifications through FCM | 8.5-8.6 |
| `audit` | Audit log of important actions | 3.13 |
| `common` | Security config, error handling, request ID logging, OpenAPI | 2.7-2.8, 2.13, 2.21 |

Full organizations (multi-tenant support, spec section 14) come after
the first release. Users and tasks carry an `organization_id` from the
start, with one default organization (see *Reviewers and Account Types*).

Modules use each other only through services — for example the reviews
module calls `TaskService` to change a task's state, never
`TaskRepository` directly — so each rule lives in exactly one place.

### Package Structure

```text
backend/src/main/java/<base package>/
├── auth/
├── users/
├── tasks/
│   ├── TaskController.java
│   ├── TaskService.java
│   ├── TaskStateMachine.java
│   ├── TaskRepository.java
│   ├── Task.java
│   ├── TaskStatus.java
│   └── dto/
├── requirements/
├── responses/
├── reviews/
├── evidence/
├── filestorage/
├── sync/
├── notifications/
├── audit/
└── common/
    ├── config/
    ├── error/      # error response format + global exception handler
    ├── security/   # security config, JWT filter
    └── logging/    # request ID / correlation ID
backend/src/main/resources/
├── application.yml
└── db/migration/   # Flyway migrations (V1__..., V2__...)
```

The base package is chosen when the project is generated (task 2.1).

### Request Flow: Approving a Task

```mermaid
sequenceDiagram
    autonumber
    participant App as Mobile app
    participant F as Filters<br/>(request ID, JWT)
    participant C as Controller
    participant S as ReviewService
    participant DB as PostgreSQL
    participant N as Notifications

    App->>F: POST /api/tasks/{id}/approve<br/>Authorization: Bearer JWT
    F->>F: Add request ID, validate JWT,<br/>load user + roles
    F->>C: Authenticated request
    C->>C: Check role (manager)
    C->>S: approve(taskId, user)
    S->>DB: Load task
    S->>S: State machine: SUBMITTED → APPROVED?<br/>User is the task's reviewer?
    S->>DB: Update task, insert review,<br/>status history and audit log (one transaction)
    S-->>C: Approved task
    C-->>App: 200 OK + task DTO
    S--)N: After commit: notify worker
```

If any check fails, the service throws a business exception (for example
`TASK_INVALID_TRANSITION`) and nothing is written. A global exception
handler turns every error into the same JSON shape:

```json
{
  "timestamp": "2026-10-01T09:30:00Z",
  "status": 409,
  "code": "TASK_INVALID_TRANSITION",
  "message": "Task cannot be approved in status IN_PROGRESS",
  "requestId": "3f2a9c1e"
}
```

### API Permissions

Every endpoint checks the caller's role (`@PreAuthorize`) and, where it
matters, ownership in the service. Tasks a user may not see answer
`404`, so their existence is not revealed.

| Endpoint | Allowed | Everyone else |
|----------|---------|---------------|
| `POST /api/auth/login`, `/refresh`, `/logout` | Anyone | — |
| `GET /api/auth/me` | Any logged-in user | `401` |
| `GET /api/users` (`?role=`, `?teamManagerId=`) | Administrators, managers | `403` |
| `GET /api/users/{id}` | Administrators, managers; others only themselves | `403` |
| `POST /api/users` | Administrators | `403` |
| `PUT /api/users/{id}/team` | Administrators (a worker joins one manager's team, or leaves it) | `403` |
| `POST /api/tasks` | Managers; administrators (main tasks for managers) | `403` |
| `GET /api/tasks`, `GET /api/tasks/{id}` | Administrators and managers: all tasks of their organization; workers: tasks assigned to them and open tasks they may take (open to everyone, or to their team while its manager is active) | `404` (hidden) |
| `GET /api/tasks/team` (`?status=`) | Any logged-in user: their team members' tasks as tiles (not their own, no cancelled ones). Empty without a team, when the team's manager is deactivated, and for administrators and managers (they have no team; they see all tasks above) | `401` |
| `GET /api/teams` | Any logged-in user: every active manager's team in numbers (active members; tasks not approved or cancelled, also those of deactivated members) | `401` |
| `PUT /api/tasks/{id}` | The manager (or administrator, main task) who created the task, while DRAFT / OPEN / ASSIGNED | `403` |
| `POST/PUT/DELETE /api/tasks/{id}/requirements…` | The manager who created the task, while DRAFT / OPEN / ASSIGNED | `403` |
| `GET /api/tasks/{id}/requirements`, `…/responses`, `…/evidence` | Anyone who can see the task | `404` |
| `POST /api/tasks/{id}/assign` | The manager who created the task (to a worker); the administrator who created a main task (to a manager) | `403` |
| `POST /api/tasks/{id}/publish` (`{"scope": "TEAM" \| "EVERYONE"}`) | The manager who created the task, while DRAFT | `403` |
| `POST /api/tasks/{id}/sub-tasks` | The manager the main task is assigned to, while ASSIGNED / IN_PROGRESS / REJECTED / CORRECTION_REQUESTED (`409 MAIN_TASK_CLOSED` otherwise, `409 NOT_A_MAIN_TASK` for other tasks) | `403` |
| `GET /api/tasks/{id}/sub-tasks` | Administrators and managers | `403` / `404` |
| `POST /api/tasks/{id}/reissue` | The manager who created the task, once work has started (IN_PROGRESS / SUBMITTED / REJECTED / CORRECTION_REQUESTED / APPROVED); not a main task | `403` / `404` |
| `POST /api/tasks/{id}/take` | A worker the open task is open to; the first one wins (`409 TASK_ALREADY_TAKEN` for the others); taking it again returns it unchanged | `403` / `404` |
| `POST /api/tasks/{id}/start` | The assigned worker (main task: the assigned manager) | `403` / `404` |
| `PUT /api/tasks/{id}/requirements/{rid}/response` | The assigned worker, while IN_PROGRESS | `403` / `404` |
| `POST /api/tasks/{id}/submit` | The assigned worker, while IN_PROGRESS; every required requirement answered (files uploaded). Main task: the assigned manager, once it has sub-tasks and every one not cancelled is approved (`409 NO_SUB_TASKS` / `409 SUB_TASKS_NOT_APPROVED`) | `403` / `404` |
| `POST /api/tasks/{id}/approve`, `…/reject`, `…/request-correction` | The task's reviewer (a manager; an administrator for a main task), while SUBMITTED; never the task's worker, except a personal task a manager assigned to themself | `403` / `404` |
| `GET /api/tasks/{id}/reviews`, `GET /api/tasks/{id}/history` | Anyone who can see the task | `404` |
| `POST /api/tasks/{id}/requirements/{rid}/evidence`, `POST …/evidence/{eid}/upload-url`, `POST …/evidence/{eid}/complete`, `DELETE /api/tasks/{id}/evidence/{eid}` | The assigned worker, while IN_PROGRESS (PHOTO: JPEG/PNG up to 10 MB; DOCUMENT: PDF up to 20 MB) | `403` / `404` |
| `GET /api/tasks/{id}/evidence/{eid}/download-url` | Anyone who can see the task | `404` |
| `PUT/GET /api/files/…` (local file storage only) | Anyone with a valid signed URL from the endpoints above | `403` |

Without a valid access token every endpoint except login, refresh,
logout, health checks, API docs and signed file URLs answers `401`.

### Cross-cutting Concerns

- **Security** — stateless Spring Security: a JWT filter authenticates
  every request except login and refresh; roles are checked on each
  endpoint; passwords are hashed with BCrypt; secure headers are on.
- **Validation** — request DTOs use Bean Validation (`@NotBlank`,
  `@Size`, ...); invalid input returns `400` with a `VALIDATION_ERROR`
  code and the failing fields.
- **Transactions** — each service method that changes data runs in one
  transaction, so a state change, its history row and its audit entry are
  saved together or not at all. Notifications are sent only after the
  transaction commits.
- **Database** — PostgreSQL with Flyway migrations; the schema is never
  changed by Hibernate (`ddl-auto=validate`). Tables use UUID primary
  keys, created / updated timestamps and indexes on frequently filtered
  columns (status, assignee, due date).
- **Configuration** — settings and secrets come from environment
  variables (`.env` locally, never committed).
- **Observability** — structured logs with a request ID on every line,
  Spring Boot Actuator health checks, and CloudWatch in production.
- **API documentation** — OpenAPI / Swagger UI generated from the
  controllers.

## Offline Sync

Workers often inspect sites with a weak or no connection, so the app is
built to work fully offline and to catch up with the server later. The
local database is the app's source of truth; a **SyncManager** in
`core/synchronization/` moves changes between the device and the backend
in the background.

### What Works Offline

| Offline | Online only |
|---------|-------------|
| Open tasks already downloaded to the device | Log in |
| Create and edit draft tasks and their requirements (manager) | Assign tasks (manager) |
| Start a task | Review: approve, reject, request correction |
| | Publish an open task (manager), take an open task (worker) |
| Answer requirements, add comments | Download tasks not yet on the device |
| Take photos, attach PDF documents | |
| Submit a task (shown as *submitted locally*) | |

A task created offline gets its ID on the device and is sent to the
server as a `DRAFT` at the next sync; the manager assigns it once
online.

Online-only actions go straight to the API and show a clear message when
there is no connection.

### Sync Queue

Every offline change is written to the local database **and** added to
the sync queue in the same local transaction (see *Data Flow* above).
Each queued operation has:

| Field | Example | Purpose |
|-------|---------|---------|
| `id` | UUID created on the device | Idempotency key — the server never applies the same operation twice. |
| `entityType` | `TaskResponse` | What changed. |
| `entityId` | `8c1f…` | Which record changed. |
| `operation` | `UPDATE` | `CREATE`, `UPDATE`, `DELETE` or a task action (`START`, `SUBMIT`). |
| `payload` | `{ "value": "YES" }` | The data to send. |
| `createdAt` | `2026-10-01T09:30:00Z` | Keeps operations in order. |
| `retryCount` | `2` | How many times sending has failed. |
| `lastError` | `NETWORK_TIMEOUT` | Why the last attempt failed. |
| `status` | `PENDING` | See the states below. |

```mermaid
stateDiagram-v2
    direction LR
    [*] --> PENDING: change saved locally
    PENDING --> SYNCING: SyncManager sends it
    SYNCING --> SYNCED: server accepted
    SYNCING --> FAILED: sync failed<br/>(data kept on device,<br/>user is told)
    FAILED --> PENDING: automatic retry while online /<br/>user taps Retry
    SYNCED --> [*]
```

Operations the server accepts: `TaskResponse UPDATE`, `Evidence CREATE` /
`DELETE` and `Task START` / `SUBMIT` (workers; start and submit also the
manager of a main task), and `Task CREATE` / `UPDATE` (managers: drafts
made offline). A `Task CREATE` carries the task ID the app gave the
draft; sending it again changes nothing, and an ID of someone else's
task is refused (`409 TASK_ID_CONFLICT`).

The queue is stored in the database, not in memory, so nothing is lost
when the app is closed or the phone restarts. Its contents can be shown
in the app and inspected in tests.

### Sync Cycle

```mermaid
sequenceDiagram
    autonumber
    participant W as Worker
    participant App as App + local DB
    participant SM as SyncManager
    participant API as Backend API
    participant S3 as AWS S3

    W->>App: Answer, photo, submit (offline)
    App->>App: Save locally + queue operations
    App-->>W: Shown at once as pending
    Note over SM: Connection returns
    SM->>API: POST /api/sync/push (queued operations, in order)
    API->>API: Skip already-applied IDs,<br/>check rules, save
    API-->>SM: Result per operation
    SM->>App: Mark SYNCED / FAILED
    SM->>API: Request pre-signed URL for each registered file
    SM->>S3: Upload photos and PDFs
    SM->>API: Confirm each upload (complete)
    SM->>API: GET /api/sync/pull?since=cursor
    API-->>SM: Changed tasks, reviews, status
    SM->>App: Update local records + cursor
```

1. **Push.** `POST /api/sync/push` sends pending operations in the order
   they were created. The server records every applied operation ID in
   `sync_records`; if an ID arrives again (for example after a timeout),
   it returns the earlier result instead of applying it twice. Each
   operation goes through the same services and rules as a normal API
   call — the task state machine, role and ownership checks. Adding a
   photo or PDF is one of these operations: it registers the file
   (type, size) with the server.
2. **Files.** Once a file is registered, the app asks for a pre-signed
   upload URL, sends the file to it and confirms the upload (`complete`;
   the server checks the stored size). Files have their own upload queue
   with the same statuses (`PENDING`, `UPLOADING`, `FAILED`, `UPLOADED`)
   and retries (task 6.12); a failed upload doesn't stop the pull. A
   submit waits until all of the task's files are uploaded (task 7.5),
   so a task is never submitted with evidence the server cannot find.
3. **Pull.** `GET /api/sync/pull?since=<cursor>` returns everything that
   changed on the server since the last pull: new assignments, status
   changes, review results and reasons. The app stores the new cursor
   only after the changes are saved locally.
4. **Order per task.** If an operation for a task fails, later
   operations for the same task wait, so for example a submit is never
   sent before the answers it depends on. Other tasks keep syncing.

### When Sync Runs

The rule is simple: **whenever the device is online, the app tries to
sync.**

- As soon as the connection comes back (connectivity detection, task
  6.3).
- When the app starts or returns to the foreground.
- Shortly after a local change, grouped so that quick edits are sent
  together.
- Periodically in the background (task 6.11): about every 15 minutes
  while the device is online, also when the app is closed or the phone
  was restarted. Android schedules this with WorkManager; on iOS,
  background time is limited and decided by the system (set up in task
  12.7), so the app also syncs every time it is opened. Both platforms
  use the same SyncManager.

Only one of them syncs at a time:

- While the app is open in the foreground it syncs itself, and a
  background run that starts meanwhile skips.
- When the app comes back to the foreground, it first waits until a
  background run that is still busy has finished.
- When the app goes to the background, it lets its own running sync
  finish before the background sync may run.
- Nothing syncs while nobody is signed in.

Refreshing the login is locked across the app and the background sync:
only one of them refreshes at a time, and the other then uses the new
tokens, so a refresh token is never used twice (ADR-0003). When the app
comes back to the foreground it reloads its screens from the local
database, which may have been changed by the background sync.

### Retries and Errors

| Error | What happens |
|-------|--------------|
| No connection, timeout, `5xx` | Temporary: the operation becomes `FAILED`, the user is told and gets a **Retry** button. While the device is online the app keeps retrying automatically with a growing delay (30 s, 1 min, 2 min, … up to 5 min), and it retries at once when the connection comes back. It never gives up on unsent data. |
| `401` — access token expired | The app refreshes the token once and retries. If the refresh token has also expired, sync pauses, the queue is kept and the user is asked to sign in again; sync continues after login. |
| `4xx` business error (e.g. `TASK_INVALID_TRANSITION`) | The server refused the change: the operation becomes `FAILED` with the server's reason shown to the user (for example *"This task was cancelled by the manager"*). It is not retried automatically, because the same request would fail again; the Retry button is still there. |

Whatever happens, **data is never lost**: a failed change stays in the
local database and the sync queue until it is synced, and is never
deleted silently.

### Conflicts

The server is the source of truth for a task's status; the device is the
source of truth for the worker's own unsent answers.

- **The task changed on the server while the worker was offline** — for
  example the manager cancelled it. The worker's `SUBMIT` is rejected with
  a clear error code, the operation becomes `FAILED`, the next pull
  brings the new status, and the app shows why (*"This task was cancelled
  by the manager"*). The worker's answers stay on the device for
  reference.
- **Stale updates** — tasks carry a version number (optimistic locking).
  An operation based on an old version of a task is rejected instead of
  overwriting newer data.
- **Answers** — only the assigned worker can change a task's answers, so
  two people never edit the same response. When the same answer is
  changed several times offline, the operations are applied in order and
  the last one wins.

### Sync Status in the App

| Situation | What the user sees |
|-----------|--------------------|
| No connection | Offline banner: *"Changes saved locally. They will sync when you're online."* |
| Changes waiting | Pending badge on the task and a count of unsent changes |
| Syncing | Progress indicator |
| Submitted offline | *"Submitted locally — waiting for synchronization."* |
| Failed | *"Unable to synchronize. Your changes are saved on this device."* with a **Retry** button |
| Session expired | *"Your session has expired. Please sign in again."* |

### Built In

| Part | Tasks |
|------|-------|
| Sync queue table and recording changes | 6.1-6.2 |
| Connectivity detection | 6.3 |
| Push endpoint + SyncManager push | 6.4-6.5 |
| Pull endpoint + SyncManager pull | 6.6-6.7 |
| Retries, expired login, conflicts | 6.8-6.10 |
| Background sync, evidence upload queue | 6.11-6.12 |
| Sync status UI and tests | 6.13-6.14 |

The full sync API and edge cases are documented in `docs/offline-sync.md`
(task 11.9).
