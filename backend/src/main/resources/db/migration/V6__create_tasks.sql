-- V6: tasks.
--
-- Status values follow the task lifecycle in docs/architecture.md. The
-- worker a task is assigned to is stored in task_assignments (V-next,
-- task 3.9). Every task has its own reviewer, who by default is the
-- manager who created it. `version` is used for optimistic locking, so
-- stale updates (for example from offline devices) are detected.

CREATE TABLE tasks (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID         NOT NULL,
    title           VARCHAR(200) NOT NULL,
    description     TEXT,
    priority        VARCHAR(20)  NOT NULL,
    status          VARCHAR(30)  NOT NULL DEFAULT 'DRAFT',
    due_date        TIMESTAMPTZ  NOT NULL,
    created_by      UUID         NOT NULL,
    reviewer_id     UUID         NOT NULL,
    version         BIGINT       NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT fk_tasks_organization FOREIGN KEY (organization_id) REFERENCES organizations (id),
    CONSTRAINT fk_tasks_created_by FOREIGN KEY (created_by) REFERENCES users (id),
    CONSTRAINT fk_tasks_reviewer FOREIGN KEY (reviewer_id) REFERENCES users (id),
    CONSTRAINT ck_tasks_title_not_blank CHECK (length(trim(title)) > 0),
    CONSTRAINT ck_tasks_priority CHECK (priority IN ('LOW', 'MEDIUM', 'HIGH')),
    CONSTRAINT ck_tasks_status CHECK (status IN ('DRAFT', 'ASSIGNED', 'IN_PROGRESS', 'SUBMITTED', 'APPROVED',
                                                  'REJECTED', 'CORRECTION_REQUESTED', 'CANCELLED'))
);

CREATE INDEX ix_tasks_organization_status ON tasks (organization_id, status);
CREATE INDEX ix_tasks_due_date ON tasks (due_date);
CREATE INDEX ix_tasks_created_by ON tasks (created_by);
CREATE INDEX ix_tasks_reviewer_id ON tasks (reviewer_id);
CREATE INDEX ix_tasks_created_at ON tasks (created_at);
