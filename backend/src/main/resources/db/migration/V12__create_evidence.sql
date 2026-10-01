-- V12: evidence files (photos and PDF documents), see ADR-0005.
--
-- Only metadata is stored here; the file itself lives in file storage
-- (local disk in development, AWS S3 in production) under storage_key.
-- The ID is created on the device, so a repeated request after a lost
-- answer finds the same row instead of creating a second one.

CREATE TABLE evidence (
    id             UUID         PRIMARY KEY,
    task_id        UUID         NOT NULL,
    requirement_id UUID         NOT NULL,
    uploaded_by    UUID         NOT NULL,
    file_name      VARCHAR(255) NOT NULL,
    content_type   VARCHAR(100) NOT NULL,
    size_bytes     BIGINT       NOT NULL,
    storage_key    VARCHAR(300) NOT NULL,
    status         VARCHAR(20)  NOT NULL DEFAULT 'PENDING',
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    uploaded_at    TIMESTAMPTZ,
    CONSTRAINT fk_evidence_task FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    CONSTRAINT fk_evidence_requirement FOREIGN KEY (requirement_id)
        REFERENCES task_requirements (id) ON DELETE CASCADE,
    CONSTRAINT fk_evidence_uploaded_by FOREIGN KEY (uploaded_by) REFERENCES users (id),
    CONSTRAINT uk_evidence_storage_key UNIQUE (storage_key),
    CONSTRAINT ck_evidence_content_type CHECK (content_type IN ('image/jpeg', 'image/png', 'application/pdf')),
    CONSTRAINT ck_evidence_size CHECK (size_bytes > 0),
    CONSTRAINT ck_evidence_status CHECK (status IN ('PENDING', 'UPLOADED'))
);

CREATE INDEX ix_evidence_task_id ON evidence (task_id);
CREATE INDEX ix_evidence_requirement_id ON evidence (requirement_id);
