-- V7: task requirements and their options.
--
-- A requirement is one item the worker must complete, e.g. "Record
-- refrigerator temperature" (NUMBER, unit °C). Types follow spec section 5
-- plus DOCUMENT (a PDF, decided 2026-10-01). DROPDOWN and
-- MULTIPLE_SELECTION requirements offer options from requirement_options.
-- `position` gives the order in which requirements are shown.

CREATE TABLE task_requirements (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id     UUID         NOT NULL,
    title       VARCHAR(300) NOT NULL,
    description TEXT,
    type        VARCHAR(30)  NOT NULL,
    required    BOOLEAN      NOT NULL DEFAULT TRUE,
    position    INTEGER      NOT NULL,
    unit        VARCHAR(30),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT fk_task_requirements_task FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    CONSTRAINT uk_task_requirements_position UNIQUE (task_id, position) DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT ck_task_requirements_title_not_blank CHECK (length(trim(title)) > 0),
    CONSTRAINT ck_task_requirements_position CHECK (position >= 0),
    CONSTRAINT ck_task_requirements_type CHECK (type IN ('CHECKBOX', 'YES_NO', 'TEXT', 'NUMBER', 'DROPDOWN',
                                                          'MULTIPLE_SELECTION', 'PHOTO', 'DOCUMENT', 'COMMENT')),
    -- Only numbers have a unit
    CONSTRAINT ck_task_requirements_unit CHECK (unit IS NULL OR type = 'NUMBER')
);

CREATE INDEX ix_task_requirements_task_id ON task_requirements (task_id);

CREATE TABLE requirement_options (
    id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    requirement_id UUID         NOT NULL,
    label          VARCHAR(200) NOT NULL,
    position       INTEGER      NOT NULL,
    CONSTRAINT fk_requirement_options_requirement FOREIGN KEY (requirement_id)
        REFERENCES task_requirements (id) ON DELETE CASCADE,
    CONSTRAINT uk_requirement_options_position UNIQUE (requirement_id, position) DEFERRABLE INITIALLY DEFERRED,
    CONSTRAINT ck_requirement_options_label_not_blank CHECK (length(trim(label)) > 0)
);

CREATE INDEX ix_requirement_options_requirement_id ON requirement_options (requirement_id);
