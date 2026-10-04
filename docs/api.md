# TaskInspect — REST API

How the backend API works: conventions, errors, paging, concurrency and
the list of endpoints. The full request and response schemas are
generated from the code (OpenAPI); who may call which endpoint is in
[architecture.md — API Permissions](architecture.md#api-permissions).

## Where to Find the Schemas

When the backend runs locally (`dev` profile):

| URL | What |
|-----|------|
| http://localhost:8080/swagger-ui.html | Swagger UI: browse and try every endpoint |
| http://localhost:8080/v3/api-docs | The OpenAPI description as JSON |

Both are switched off in production (`prod` profile).

## Conventions

- **Base path**: every endpoint starts with `/api`. JSON in, JSON out
  (`Content-Type: application/json`); only the file bytes themselves go
  to a signed upload URL (see "Evidence File Uploads").
- **Authentication**: send the access token from
  `POST /api/auth/login` as `Authorization: Bearer <token>`. Without a
  valid token every endpoint answers `401`, except login, refresh,
  logout, the health check (`/actuator/health`), the API docs and
  signed file URLs. Details: [authentication.md](authentication.md).
- **IDs** are UUIDs. Tasks, requirements, evidence files and sync
  operations created on a device carry the ID the device gave them, so
  sending the same change twice is harmless (see "Sending Again" below).
- **Times** are ISO-8601 instants in UTC, e.g. `2026-10-02T09:00:00Z`.
- **Enums** are upper case strings: task status `DRAFT`, `OPEN`,
  `ASSIGNED`, `IN_PROGRESS`, `SUBMITTED`, `APPROVED`, `REJECTED`,
  `CORRECTION_REQUESTED`, `CANCELLED`; priority `LOW`, `MEDIUM`, `HIGH`;
  requirement types `CHECKBOX`, `YES_NO`, `TEXT`, `COMMENT`, `NUMBER`,
  `DROPDOWN`, `MULTIPLE_SELECTION`, `PHOTO`, `DOCUMENT`.
- **Request IDs**: every response has an `X-Request-Id` header (the
  client may send its own). The same ID is in every server log line of
  the request and in error responses, so a problem a user reports can
  be found in the logs.

## Errors

Every error has the same JSON shape:

```json
{
  "timestamp": "2026-10-02T09:15:00Z",
  "status": 409,
  "code": "TASK_INVALID_TRANSITION",
  "message": "A SUBMITTED task cannot be started",
  "requestId": "3f2c9a6e-...",
  "errors": [
    { "field": "title", "message": "must not be blank" }
  ]
}
```

- `code` is stable and meant for programs (the app decides what to do
  from it); `message` is for people and may change.
- `errors` lists the invalid fields, only for `VALIDATION_ERROR` (and a
  few rules that name several items, e.g. the missing requirements of
  `REQUIREMENTS_MISSING`).
- In production `message` never contains stack traces or internal
  details.

The usual HTTP statuses: `400` invalid input, `401` no or invalid token,
`403` not allowed, `404` not found **or not visible to the caller** (a
task the caller may not see answers `404`, so its existence is not
revealed), `409` the request conflicts with the current state, `500` unexpected
error. (`FILE_TOO_LARGE` is `400` when a file is registered and `413` if
an upload to a local storage URL is bigger than registered.)

### Error Codes

| Area | Codes |
|------|-------|
| Request | `VALIDATION_ERROR` (see `errors`), `MALFORMED_REQUEST` (unreadable JSON), `INVALID_PARAMETER`, `METHOD_NOT_ALLOWED`, `UNSUPPORTED_MEDIA_TYPE`, `NOT_FOUND`, `INTERNAL_ERROR` |
| Login and tokens | `UNAUTHORIZED` (no token), `INVALID_TOKEN` (expired, tampered, other issuer), `INVALID_CREDENTIALS`, `ACCOUNT_DISABLED`, `INVALID_REFRESH_TOKEN`, `FORBIDDEN` |
| Users and teams | `USER_NOT_FOUND`, `EMAIL_ALREADY_USED`, `NOT_A_WORKER`, `INVALID_TEAM_MANAGER` |
| Tasks | `TASK_NOT_FOUND`, `TASK_NOT_EDITABLE`, `TASK_INVALID_TRANSITION`, `TASK_ALREADY_APPROVED`, `TASK_ALREADY_CANCELLED`, `VERSION_CONFLICT`, `TASK_HAS_NO_REQUIREMENTS`, `TASK_ID_CONFLICT`, `INVALID_REVIEWER`, `INVALID_ASSIGNEE`, `REVIEWER_IS_ASSIGNEE` |
| Open tasks, sub-tasks, registering again | `TEAM_HAS_NO_MEMBERS`, `TASK_ALREADY_TAKEN`, `MAIN_TASK_NOT_PUBLISHABLE`, `NOT_A_MAIN_TASK`, `MAIN_TASK_CLOSED`, `TASK_NOT_REISSUABLE` |
| Requirements | `REQUIREMENT_NOT_FOUND`, `INVALID_REQUIREMENT`, `INVALID_ORDER`, `REQUIREMENT_ID_CONFLICT` |
| Answers | `INVALID_RESPONSE`, `USE_EVIDENCE_UPLOAD` (PHOTO / DOCUMENT are answered with files), `RESPONSES_LOCKED`, `REQUIREMENT_NOT_MARKED` (during a correction only marked requirements change) |
| Evidence files | `EVIDENCE_NOT_FOUND`, `INVALID_EVIDENCE_TYPE`, `FILE_TOO_LARGE`, `EVIDENCE_ID_CONFLICT`, `EVIDENCE_ALREADY_UPLOADED`, `EVIDENCE_NOT_UPLOADED`, `UPLOAD_INCOMPLETE`, `EVIDENCE_LOCKED`, `INVALID_SIGNATURE`, `FILE_NOT_FOUND` |
| Submit and review | `REQUIREMENTS_MISSING`, `NO_SUB_TASKS`, `SUB_TASKS_NOT_APPROVED`, `NOT_TASK_REVIEWER` |
| Sync | `INVALID_PAYLOAD`, `UNSUPPORTED_OPERATION`, `OPERATION_ID_CONFLICT`, `EARLIER_OPERATION_REJECTED` |

## Lists and Paging

List endpoints that can grow (`GET /api/tasks`, `GET /api/tasks/team`,
`GET /api/users`) take `page` (from 0, default 0) and `size` (1–100,
default 20) and answer:

```json
{ "content": [ ... ], "page": 0, "size": 20, "totalElements": 42, "totalPages": 3 }
```

Tasks are sorted by due date. `GET /api/tasks` also filters by
`status`, `priority`, `dueFrom` and `dueBefore`; `GET /api/tasks/team`
by `status`.

## Changes Made at the Same Time

- **Versions**: a task has a `version` that goes up with every change.
  `PUT /api/tasks/{id}` must send the version the client last saw; if
  someone changed the task meanwhile the answer is
  `409 VERSION_CONFLICT` and nothing is overwritten. The client reloads
  the task and tries again.
- **Status actions** (assign, start, submit, approve, ...) check the
  current status on the server; an action that no longer fits answers
  `409 TASK_INVALID_TRANSITION` (or a more specific code such as
  `TASK_ALREADY_TAKEN`).

## Sending Again

The mobile app works offline and sends its changes later, sometimes
twice (a lost answer, a retry). The API is built for that:

- Objects created on the device keep the device's ID. Registering the
  same evidence file again returns the existing one (`200` instead of
  `201`); a different object with an ID that is already used answers
  `409 ..._ID_CONFLICT` (`TASK_ID_CONFLICT`, `REQUIREMENT_ID_CONFLICT`,
  `EVIDENCE_ID_CONFLICT`).
- `POST /api/sync/push` remembers each operation's ID and skips
  operations it has already applied. See
  [offline-sync.md](offline-sync.md).
- Taking a task you already took, completing an upload twice or
  removing an unknown device token are harmless.

## Evidence File Uploads

Files never go through a JSON request. The app:

1. registers the file: `POST /api/tasks/{taskId}/requirements/{requirementId}/evidence`
   with its ID, name, content type and size (PHOTO: JPEG / PNG up to
   10 MB, DOCUMENT: PDF up to 20 MB);
2. asks for an upload URL: `POST .../evidence/{evidenceId}/upload-url`
   and uploads the bytes with the returned method and headers, **without**
   the `Authorization` header (the URL is signed and expires);
3. confirms: `POST .../evidence/{evidenceId}/complete` — the server checks
   the stored size and marks the file `UPLOADED`.

Viewing works the same way: `GET .../evidence/{evidenceId}/download-url`
returns a short-lived signed URL. With `STORAGE_TYPE=s3` the URLs point
to S3 directly; with local storage (development) to `/api/files/...`.

## Endpoints

Grouped by area, with the summary shown in Swagger. Who may call each
one: [API Permissions](architecture.md#api-permissions).

### Authentication

| Method | Path | Summary |
|--------|------|---------|
| POST | `/api/auth/login` | Log in with email and password |
| POST | `/api/auth/refresh` | Get new tokens with a refresh token |
| POST | `/api/auth/logout` | Log out |
| GET | `/api/auth/me` | Who am I? |

### Users and Teams

| Method | Path | Summary |
|--------|------|---------|
| GET | `/api/users` | List users |
| POST | `/api/users` | Create a user |
| GET | `/api/users/{id}` | Get a user |
| PUT | `/api/users/{id}/team` | Set a worker's team |
| GET | `/api/teams` | List teams |

### Tasks

| Method | Path | Summary |
|--------|------|---------|
| GET | `/api/tasks` | List tasks |
| POST | `/api/tasks` | Create a draft task |
| GET | `/api/tasks/team` | List my team's tasks |
| GET | `/api/tasks/{id}` | Get a task |
| PUT | `/api/tasks/{id}` | Edit a task |
| POST | `/api/tasks/{id}/assign` | Assign a task to a worker |
| POST | `/api/tasks/{id}/publish` | Publish a task as an open task |
| POST | `/api/tasks/{id}/take` | Take an open task |
| POST | `/api/tasks/{id}/start` | Start working on a task |
| POST | `/api/tasks/{id}/sub-tasks` | Add a sub-task to a main task |
| GET | `/api/tasks/{id}/sub-tasks` | List a main task's sub-tasks |
| POST | `/api/tasks/{id}/reissue` | Register a task again for the same worker |
| GET | `/api/tasks/{id}/history` | A task's history |

### Requirements and Answers

| Method | Path | Summary |
|--------|------|---------|
| GET | `/api/tasks/{taskId}/requirements` | List a task's requirements |
| POST | `/api/tasks/{taskId}/requirements` | Add a requirement |
| PUT | `/api/tasks/{taskId}/requirements/{requirementId}` | Change a requirement |
| DELETE | `/api/tasks/{taskId}/requirements/{requirementId}` | Delete a requirement |
| PUT | `/api/tasks/{taskId}/requirements/order` | Change the order of the requirements |
| GET | `/api/tasks/{taskId}/responses` | List the answers of a task |
| PUT | `/api/tasks/{taskId}/requirements/{requirementId}/response` | Answer a requirement |

### Evidence Files

| Method | Path | Summary |
|--------|------|---------|
| GET | `/api/tasks/{taskId}/evidence` | List a task's evidence files |
| POST | `/api/tasks/{taskId}/requirements/{requirementId}/evidence` | Register an evidence file before uploading it |
| POST | `/api/tasks/{taskId}/evidence/{evidenceId}/upload-url` | Get a URL for uploading the file |
| POST | `/api/tasks/{taskId}/evidence/{evidenceId}/complete` | Confirm that the file was uploaded |
| GET | `/api/tasks/{taskId}/evidence/{evidenceId}/download-url` | Get a URL for viewing an uploaded file |
| DELETE | `/api/tasks/{taskId}/evidence/{evidenceId}` | Remove an evidence file |

### Submit and Review

| Method | Path | Summary |
|--------|------|---------|
| POST | `/api/tasks/{id}/submit` | Submit a task for review |
| POST | `/api/tasks/{id}/approve` | Approve a submitted task |
| POST | `/api/tasks/{id}/reject` | Reject a submitted task |
| POST | `/api/tasks/{id}/request-correction` | Request a correction |
| GET | `/api/tasks/{id}/reviews` | List a task's reviews |

### Sync and Devices

| Method | Path | Summary |
|--------|------|---------|
| POST | `/api/sync/push` | Send changes made on the device |
| GET | `/api/sync/pull` | Get what changed on the server |
| PUT | `/api/devices` | Register this device for push notifications |
| DELETE | `/api/devices` | Stop push notifications on this device |

### Other

| Method | Path | Summary |
|--------|------|---------|
| GET | `/actuator/health` | Health check (public) |
| PUT / GET | `/api/files/{key}` | Signed upload / download URLs of the local file storage (development) |
