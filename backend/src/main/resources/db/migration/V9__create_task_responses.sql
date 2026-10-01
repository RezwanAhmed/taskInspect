-- V9: the worker's answers to requirements.
--
-- One response per requirement. Which value column is used depends on the
-- requirement type: boolean_value (CHECKBOX, YES_NO), text_value (TEXT,
-- COMMENT), number_value (NUMBER), selected_option_ids (DROPDOWN,
-- MULTIPLE_SELECTION). Photos and documents are stored as evidence
-- (task 5.17). `comment` is an optional note on any requirement.

CREATE TABLE task_responses (
    id                  UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id             UUID           NOT NULL,
    requirement_id      UUID           NOT NULL,
    responded_by        UUID           NOT NULL,
    boolean_value       BOOLEAN,
    text_value          TEXT,
    number_value        NUMERIC(19, 4),
    selected_option_ids UUID[],
    comment             TEXT,
    created_at          TIMESTAMPTZ    NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ    NOT NULL DEFAULT now(),
    CONSTRAINT fk_task_responses_task FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    CONSTRAINT fk_task_responses_requirement FOREIGN KEY (requirement_id)
        REFERENCES task_requirements (id) ON DELETE CASCADE,
    CONSTRAINT fk_task_responses_responded_by FOREIGN KEY (responded_by) REFERENCES users (id),
    CONSTRAINT uk_task_responses_requirement UNIQUE (requirement_id)
);

CREATE INDEX ix_task_responses_task_id ON task_responses (task_id);
