-- V10: history of every task status change.
--
-- One row per change: from which status (NULL when the task is created)
-- to which, who did it, when, and an optional reason (e.g. why a task was
-- rejected). These rows build the task history timeline.

CREATE TABLE task_status_history (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id     UUID        NOT NULL,
    from_status VARCHAR(30),
    to_status   VARCHAR(30) NOT NULL,
    changed_by  UUID        NOT NULL,
    reason      TEXT,
    changed_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_task_status_history_task FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    CONSTRAINT fk_task_status_history_changed_by FOREIGN KEY (changed_by) REFERENCES users (id)
);

CREATE INDEX ix_task_status_history_task_id ON task_status_history (task_id, changed_at);
