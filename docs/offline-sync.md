# TaskInspect — Offline Sync

The sync API and its edge cases. The concepts — what works offline, the
sync queue, when sync runs, the status the user sees — are in
[architecture.md — Offline Sync](architecture.md#offline-sync); why the
app is offline-first: [ADR-0004](decisions/0004-offline-first-mobile-architecture.md).

A sync cycle on the device is always **push → file uploads → pull**:

1. `POST /api/sync/push` sends the queued changes.
2. Evidence files the server now knows are uploaded with signed URLs
   ([api.md — Evidence File Uploads](api.md#evidence-file-uploads)).
3. `GET /api/sync/pull` loads what changed on the server.

If the push fails (no connection, server error), nothing else is tried.
A failed upload does not stop the pull, but the cycle counts as failed
and is retried.

## Push

`POST /api/sync/push` (any signed-in user):

```json
{
  "operations": [
    {
      "id": "6f1c0d2e-...",
      "entityType": "TaskResponse",
      "entityId": "<requirement id>",
      "taskId": "<task id>",
      "operation": "UPDATE",
      "payload": { "booleanValue": true, "comment": "Checked twice" }
    }
  ]
}
```

- `id` is created on the device for every queued change and is the
  **idempotency key**. 1–100 operations per request, in the order they
  were made.
- `payload` is the body the matching API call takes (validated the same
  way).

The answer has one result per operation, in the same order:

```json
{
  "results": [
    { "id": "6f1c0d2e-...", "status": "APPLIED" },
    { "id": "91aa...", "status": "REJECTED", "code": "TASK_INVALID_TRANSITION", "message": "..." },
    { "id": "c03b...", "status": "SKIPPED", "code": "EARLIER_OPERATION_REJECTED", "message": "..." }
  ]
}
```

| Status | Meaning | What the app does |
|--------|---------|-------------------|
| `APPLIED` | Applied now, or already applied by an earlier push | Removes it from the queue |
| `REJECTED` | Refused by the server's rules (`code` as in the normal API); the same request would fail again | Marks it `FAILED` with the reason; not retried automatically (the user can tap Retry) |
| `SKIPPED` | Not tried because an earlier operation **of the same task** was rejected in this push | Stays queued behind the failed one |

The whole request fails (and the app retries the batch later) only for
problems that are not about one operation, e.g. the database being down
or an invalid request body (`400`). Operations applied before that are
already recorded, so sending the batch again is safe.

### Supported Operations

| `entityType` | `operation` | `entityId` | `payload` | Who |
|--------------|-------------|------------|-----------|-----|
| `TaskResponse` | `UPDATE` | requirement ID | answer: `booleanValue` / `textValue` / `numberValue` / `selectedOptionIds`, `comment` | Worker |
| `Evidence` | `CREATE` | evidence ID (= `payload.id`) | `id`, `requirementId`, `fileName`, `contentType`, `sizeBytes` | Worker |
| `Evidence` | `DELETE` | evidence ID | — | Worker |
| `Task` | `START` | task ID | optional `version` (the task version the device saw) | Worker; manager of a main task |
| `Task` | `SUBMIT` | task ID | `version` (sent, not checked) | Worker; manager of a main task |
| `Task` | `CREATE` | task ID (created on the device) | `title`, `description`, `priority`, `dueDate`, `reviewerId` | Manager |
| `Task` | `UPDATE` | task ID | the same plus `version` | Manager |
| `Requirement` | `CREATE` / `UPDATE` | requirement ID | `title`, `description`, `type`, `required`, `unit`, `options` | Manager |
| `Requirement` | `DELETE` | requirement ID | — | Manager |
| `RequirementOrder` | `UPDATE` | task ID | `requirementIds` in the new order | Manager |

Every operation runs in its own transaction through the same services
and rules as the API endpoint: role and ownership checks, the task state
machine, requirement validation. Anything else answers
`REJECTED UNSUPPORTED_OPERATION`; a payload that doesn't fit answers
`INVALID_PAYLOAD` or `VALIDATION_ERROR`.

### Rules and Edge Cases

- **Sent twice** (lost answer, app closed during sync): every applied
  operation is recorded in `sync_records`, so its ID is answered
  `APPLIED` again without applying it. An operation ID that another user
  already used is `REJECTED OPERATION_ID_CONFLICT`. Rejected operations
  are not recorded, so they can be sent again after a fix.
- **Order per task**: once an operation of a task is rejected, the later
  ones of that task in the same push are `SKIPPED`, and the app holds
  that task's queue until the failed one is retried — a submit never
  overtakes the answers it depends on. Other tasks go on.
- **Submit waits for files**: the app sends a `SUBMIT` only when every
  file of the task is uploaded; the server would refuse it anyway
  (`EVIDENCE_NOT_UPLOADED`).
- **A refused submit** (e.g. `REQUIREMENTS_MISSING`): the task is back
  `IN_PROGRESS` on the device so the worker can fix it; the refused
  `SUBMIT` stays visible with its reason, does not hold back the task's
  other changes, and the next submit replaces it.
- **Started on an old version**: a `START` whose `version` differs from
  the server's is `REJECTED VERSION_CONFLICT` (the task changed, e.g. it
  was edited or cancelled). Retry sends it with the version from the last
  pull. `SUBMIT` has no version check: the state machine and the
  requirement checks decide.
- **Edited drafts**: a `Task UPDATE` raises the task's version on the
  server; the device raises its copy the same way, so a later edit still
  in the queue is not refused as made on an old version.
- **IDs from the device**: a `CREATE` with an ID that already belongs to
  the same object changes nothing; an ID that belongs to something else
  is `REJECTED` (`TASK_ID_CONFLICT`, `REQUIREMENT_ID_CONFLICT`,
  `EVIDENCE_ID_CONFLICT`). Deleting a requirement that is already gone
  is fine.
- **Changes made at the same time** on the server (optimistic locking)
  are `REJECTED VERSION_CONFLICT` instead of overwriting.
- **Expired login during sync**: the app refreshes the token once; if
  the refresh token is refused, sync pauses and the queue is kept until
  the same user signs in again ([authentication.md](authentication.md)).

## Pull

`GET /api/sync/pull` (any signed-in user), optionally with
`?since=<cursor>`:

```json
{
  "cursor": "2026-10-02T09:15:00Z",
  "taskIds": ["...", "..."],
  "tasks": [
    { "task": { "id": "...", "status": "IN_PROGRESS", "version": 4, "...": "..." },
      "requirements": [ { "id": "...", "type": "YES_NO", "...": "..." } ],
      "latestReview": { "result": "CORRECTION_REQUESTED", "reason": "...",
                      "requirements": [ { "requirementId": "...", "comment": "Too dark" } ] } }
  ],
  "tileIds": ["..."],
  "tiles": [ { "id": "...", "title": "...", "status": "ASSIGNED", "assignee": { "...": "..." } } ],
  "teamVersion": "..."
}
```

| Field | Meaning |
|-------|---------|
| `cursor` | Server time of this pull; send it as `since` next time |
| `taskIds` | **Every** task the user may see now — the app removes all others |
| `tasks` | The tasks that changed since `since` (all of them without `since`), each with its requirements and latest review |
| `tileIds`, `tiles` | The same for team members' tasks shown as tiles (no requirements) |
| `teamVersion` | Changes when the user's team changes |

- Without `since` (first pull, after signing in) everything is sent.
- **Overlap**: changes from one minute before `since` are sent again, so
  a change committed while the previous pull was running is never
  missed; the app simply stores them once more.
- **Visibility**: the same rules as the task list (assigned tasks, open
  tasks the user may take, all tasks for managers and administrators).
  A task that is no longer visible (reassigned, team changed) disappears
  through `taskIds`.
- **Team changes**: a task can become visible without changing itself
  (e.g. a worker joins a team), which a cursor can't show. When
  `teamVersion` differs from the last pull, the app pulls once more
  without `since`.
- Answers and files are not part of the pull: the worker's own are on
  the device; reviewers read them through the API.

### Storing a Pull on the Device

- The changed tasks, the removal of the invisible ones and the new
  cursor are saved in **one local transaction**; if anything fails
  half-way, the next pull loads the same changes again.
- **A task with unsent local changes keeps its local version**, so the
  server's older copy cannot undo the worker's work; it is updated by a
  later pull once the queue is empty. The latest review is stored even
  then (it doesn't touch the worker's changes) — so the worker sees what
  to correct.

## Where It Is Implemented

| Part | Code |
|------|------|
| Push endpoint and rules | `backend/.../sync/SyncService.java`, `SyncController.java` |
| Pull endpoint | `backend/.../sync/SyncPullService.java` |
| Applied operations | `sync_records` table ([database.md](database.md)) |
| Queue, push, pull, retries | `mobile/lib/core/synchronization/` (`SyncManager`, `SyncQueue`, `SyncScheduler`, `BackgroundSync`) |
| Storing pulled tasks | `mobile/lib/features/tasks/data/local/task_local_data_source.dart` |

Tests: `backend/src/test/.../sync/` (push, pull, team pull, records) and
`mobile/test/core/synchronization/` including an end-to-end offline
scenario; see [testing.md](testing.md).
