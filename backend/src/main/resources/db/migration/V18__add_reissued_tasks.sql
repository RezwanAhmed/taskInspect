-- V18: registering a task again (Phase 7A, docs/architecture.md
-- "Registering a Task Again").
--
-- A manager can register a new task for the same worker from one whose
-- work has started; reissued_from_id links the new task to the one it was
-- made from (NULL for every other task). Tasks are not deleted in normal
-- use; SET NULL only keeps test clean-ups simple.

ALTER TABLE tasks ADD COLUMN reissued_from_id UUID;
ALTER TABLE tasks ADD CONSTRAINT fk_tasks_reissued_from FOREIGN KEY (reissued_from_id) REFERENCES tasks (id)
    ON DELETE SET NULL;
CREATE INDEX ix_tasks_reissued_from_id ON tasks (reissued_from_id);
