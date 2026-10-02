-- V16: open tasks (Phase 7A, docs/architecture.md "Open Tasks").
--
-- A manager can publish a task without an assignee (status OPEN). While
-- the task is OPEN, open_scope says who may take it: the manager's TEAM or
-- EVERYONE in the organization; in every other status it is NULL.

ALTER TABLE tasks DROP CONSTRAINT ck_tasks_status;
ALTER TABLE tasks ADD CONSTRAINT ck_tasks_status CHECK (status IN ('DRAFT', 'OPEN', 'ASSIGNED', 'IN_PROGRESS',
                                                                   'SUBMITTED', 'APPROVED', 'REJECTED',
                                                                   'CORRECTION_REQUESTED', 'CANCELLED'));

ALTER TABLE tasks ADD COLUMN open_scope VARCHAR(20);

ALTER TABLE tasks ADD CONSTRAINT ck_tasks_open_scope CHECK (open_scope IN ('TEAM', 'EVERYONE'));

ALTER TABLE tasks ADD CONSTRAINT ck_tasks_open_scope_only_when_open
    CHECK ((status = 'OPEN') = (open_scope IS NOT NULL));
