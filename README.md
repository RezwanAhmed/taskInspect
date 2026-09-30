# TaskInspect

**Offline-first task and inspection management platform.**

TaskInspect lets a manager create a task, define the requirements that must be
completed, and assign it to a worker. The worker completes each requirement on
a mobile device — with structured answers, photos and PDF documents — even without a
network connection, then submits it for review. A reviewer approves the task,
rejects it, or requests a correction, and every step is recorded in the task's
history.

> **Status:** in early development — the repository currently contains the
> project structure and documentation; the app and API are being built.

## Project Overview

TaskInspect is built as a small but production-oriented product rather than a
CRUD demo. It consists of:

- **Mobile app** — Flutter, where workers execute tasks and managers review them.
  Works offline and synchronizes in the background when connectivity returns.
  Released on Google Play first, then on the Apple App Store.
- **Backend API** — Java / Spring Boot REST API with PostgreSQL, which owns the
  business rules: who can do what, and which task state changes are allowed.
- **Cloud storage** — evidence files (photos, PDFs) are stored in object storage (AWS S3), not in
  the database.

The same workflow fits many industries — kitchen safety checks, facility
inspections, maintenance rounds, audits — because requirements are
configurable per task.

## Core Workflow

```mermaid
flowchart LR
    A[Create task] --> B[Define requirements]
    B --> C[Assign to worker]
    C --> D[Execute requirements]
    D --> E[Attach evidence]
    E --> F[Submit]
    F --> G{Review}
    G -->|Approve| H[Approved]
    G -->|Reject / request correction| I[Correct]
    I --> F
```

1. **Create** — a manager creates a task with a title, description, priority
   and deadline.
2. **Define requirements** — each requirement has a type: checkbox, yes/no,
   text, number, dropdown, multiple selection, photo, PDF document or comment.
3. **Assign** — the task is assigned to a worker.
4. **Execute** — the worker completes each requirement on their phone. This works
   offline: answers are saved locally and synchronized later.
5. **Attach evidence** — photos, PDF documents, values and comments show that the work was
   actually done.
6. **Submit** — the worker submits the task for review.
7. **Review** — the reviewer checks every response and piece of evidence, then
   approves, rejects or requests a correction with a reason.
8. **Correct and resubmit** — a rejected task returns to the worker, who fixes
   it and submits again until it is approved.

The backend enforces every step. For example, a worker cannot approve their own
task, and an approved task cannot be modified — even through a hand-crafted API
request.

### Example: Daily Kitchen Safety Inspection

| Requirement                         | Type    |
|-------------------------------------|---------|
| Is the gas connection safe?         | Yes/No  |
| Record the refrigerator temperature | Number (°C) |
| Is the fire extinguisher available? | Yes/No  |
| Check the electrical equipment      | Checkbox |
| Take a photo of the kitchen         | Photo   |

The worker completes the inspection with no internet connection and submits it.
The app shows *"Submitted locally — waiting for synchronization"* and uploads
everything once the connection returns. The manager reviews the evidence and
asks for the refrigerator photo to be retaken; the worker retakes it and
resubmits, and the manager approves. The task history shows the full lifecycle.

## Features

Planned for the first release:

### Task management

- Create tasks with a title, description, priority and deadline
- Configurable requirements per task — checkbox, yes/no, text, number (with
  unit), dropdown, multiple selection, photo, PDF document and comment
- Assign tasks to workers and track them by status: pending, in progress,
  submitted, approved, rejected
- A strict task state machine: invalid status changes are rejected by the API

### Task execution (mobile)

- Dashboard with task counts per status, and a filterable task list
- Step-by-step requirement execution with structured answers and comments
- Photo evidence from the camera or gallery, compressed before upload
- PDF documents (certificates, reports) attached from the device's files
- Save progress at any time and continue later

### Offline-first synchronization

- Tasks, answers, photos and PDFs are stored on the device, so work continues
  without a network connection
- Local changes are queued and synchronized in the background when
  connectivity returns, with retries and conflict handling
- File uploads are queued separately, so a slow upload never blocks a
  submission
- The app always shows the sync state: offline, syncing, synced or failed

### Review

- Review every response and piece of evidence of a submitted task
- Approve, reject or request a correction with a reason
- Reject sends the whole task back; a correction request sends back only
  the requirements that need fixing
- Each task has its own reviewer — one manager can assign and another review
- Solo users can review their own tasks, like a personal checklist
- A full history timeline for every task

### Security and platform

- JWT authentication with access and refresh tokens
- Role-based access (administrator, manager, worker) enforced by the backend
- Audit log of important actions (task created, assigned, submitted,
  approved, rejected)
- Push notifications for assignments, submissions and review results
- Evidence files (photos, PDFs) stored in AWS S3; only metadata is kept in the database

## Tech Stack

| Area     | Technologies |
|----------|--------------|
| Mobile   | Flutter, Dart, BLoC, Clean Architecture, Material 3, local database, secure storage, background sync, camera + image compression |
| Backend  | Java, Spring Boot (Web, Security, Data JPA / Hibernate), JWT, OpenAPI / Swagger |
| Database | PostgreSQL (Flyway migrations), Redis where useful |
| Cloud    | AWS S3 (evidence), AWS CloudWatch (logging), Firebase Cloud Messaging (push notifications) |
| DevOps   | Docker, Docker Compose, GitHub Actions (build, test, deploy) |
| Testing  | JUnit, Mockito, Spring Boot Test, Flutter unit / widget / integration tests |
| Tools    | Git, GitHub, Gradle, Android Studio, IntelliJ IDEA, Xcode (iOS, on a cloud Mac) |

## Repository Structure

```text
taskInspect/
├── mobile/            # Flutter app — BLoC, feature-based Clean Architecture, offline-first
├── backend/           # Java / Spring Boot REST API — Security + JWT, JPA, PostgreSQL
├── infrastructure/    # Docker, deployment and AWS configuration
├── docs/              # Architecture, API, database, sync and deployment docs
│   └── decisions/     # Architecture Decision Records
├── .github/           # GitHub Actions workflows (planned)
├── docker-compose.yml # Local PostgreSQL (backend service added later)
├── LICENSE            # All rights reserved
└── README.md
```

Each top-level folder has its own `README.md` describing what it will
contain. Folders and files marked *planned* are added in the phase that needs
them (see the roadmap below).

## Roadmap

The project is built in small steps, one phase at a time.

| Phase | Focus | Status |
|-------|-------|--------|
| 1  | Repository and architecture — structure, README, architecture docs, ADRs | Done |
| 2  | Backend foundation — Spring Boot, PostgreSQL, Flyway, JWT authentication, users and roles | Planned |
| 3  | Task management (backend) — tasks, requirements, assignment, state machine, audit log | Planned |
| 4  | Flutter foundation — project setup, theme, routing, API client, local database, login | Planned |
| 5  | Task execution (mobile) — dashboard, task list, requirement inputs, photo and PDF evidence | Planned |
| 6  | Offline synchronization — sync queue, push / pull, retries, conflicts, background sync | Planned |
| 7  | Review workflow — submit, approve / reject / request correction, resubmit, history | Planned |
| 8  | Cloud — S3 evidence storage, push notifications, Docker image, cloud deployment | Planned |
| 9  | Testing — backend unit / integration / security tests, Flutter unit / widget / integration tests | Planned |
| 10 | CI/CD — GitHub Actions for build, test, analysis, Docker images and deployment | Planned |
| 11 | Production release — signed Android app, Google Play, monitoring, final docs | Planned |
| 12 | iOS release — iOS build on a cloud Mac, push notifications, TestFlight, App Store | Planned |

Android comes first; the iOS release follows the Google Play release.
The app is built with both platforms in mind from the start (see
[ADR-0001](docs/decisions/0001-flutter-for-cross-platform-mobile.md)).

Setup, API, testing and deployment instructions will be added to this README
as those parts are built.

## License

Copyright (c) 2026 Rezwan Ahmed Heera. All rights reserved.

The source code is public so that it can be viewed, but it is not open
source: it may not be used, copied, modified or distributed without
written permission. See [LICENSE](LICENSE).
