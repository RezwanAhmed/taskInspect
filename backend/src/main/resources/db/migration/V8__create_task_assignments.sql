-- V8: task assignments.
--
-- tasks.assignee_id is the worker a task is currently assigned to (fast
-- to filter on: "my tasks"). task_assignments keeps the history of who
-- assigned the task to whom and when.

ALTER TABLE tasks ADD COLUMN assignee_id UUID;
ALTER TABLE tasks ADD CONSTRAINT fk_tasks_assignee FOREIGN KEY (assignee_id) REFERENCES users (id);
CREATE INDEX ix_tasks_assignee_id ON tasks (assignee_id);

CREATE TABLE task_assignments (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id     UUID        NOT NULL,
    assignee_id UUID        NOT NULL,
    assigned_by UUID        NOT NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_task_assignments_task FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    CONSTRAINT fk_task_assignments_assignee FOREIGN KEY (assignee_id) REFERENCES users (id),
    CONSTRAINT fk_task_assignments_assigned_by FOREIGN KEY (assigned_by) REFERENCES users (id)
);

CREATE INDEX ix_task_assignments_task_id ON task_assignments (task_id);
