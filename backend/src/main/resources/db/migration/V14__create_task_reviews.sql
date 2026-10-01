-- V14: review results of submitted tasks.
--
-- One row per review: approved, rejected (with a reason) or correction
-- requested (with the marked requirements, each with a comment). Together
-- with the status history this is the task's review record.

CREATE TABLE task_reviews (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id     UUID        NOT NULL,
    reviewer_id UUID        NOT NULL,
    result      VARCHAR(30) NOT NULL,
    reason      TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_task_reviews_task FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    CONSTRAINT fk_task_reviews_reviewer FOREIGN KEY (reviewer_id) REFERENCES users (id),
    CONSTRAINT ck_task_reviews_result CHECK (result IN ('APPROVED', 'REJECTED', 'CORRECTION_REQUESTED'))
);

CREATE INDEX ix_task_reviews_task_id ON task_reviews (task_id, created_at);

-- The requirements a correction request sends back to the worker.
CREATE TABLE task_review_items (
    review_id      UUID NOT NULL,
    requirement_id UUID NOT NULL,
    comment        TEXT NOT NULL,
    CONSTRAINT pk_task_review_items PRIMARY KEY (review_id, requirement_id),
    CONSTRAINT fk_task_review_items_review FOREIGN KEY (review_id) REFERENCES task_reviews (id) ON DELETE CASCADE,
    CONSTRAINT fk_task_review_items_requirement FOREIGN KEY (requirement_id) REFERENCES task_requirements (id)
        ON DELETE CASCADE
);
