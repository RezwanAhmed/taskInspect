-- V17: sub-tasks (Phase 7A, docs/architecture.md "Tasks for Managers and
-- Sub-tasks").
--
-- A manager passes a main task on in sub-tasks; parent_task_id links a
-- sub-task to its main task (NULL for every other task). Tasks are not
-- deleted in normal use; SET NULL only keeps test clean-ups simple.

ALTER TABLE tasks ADD COLUMN parent_task_id UUID;
ALTER TABLE tasks ADD CONSTRAINT fk_tasks_parent_task FOREIGN KEY (parent_task_id) REFERENCES tasks (id)
    ON DELETE SET NULL;
CREATE INDEX ix_tasks_parent_task_id ON tasks (parent_task_id);
