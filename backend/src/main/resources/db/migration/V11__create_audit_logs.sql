-- V11: audit log of important actions (who did what, when).
--
-- actor_id is NULL for actions without a known user (e.g. a failed login
-- with an unknown email, or the system creating the first administrator).
-- request_id links the entry to the server logs of the same request.

CREATE TABLE audit_logs (
    id              UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID,
    actor_id        UUID,
    action          VARCHAR(50)  NOT NULL,
    entity_type     VARCHAR(50),
    entity_id       UUID,
    details         TEXT,
    request_id      VARCHAR(64),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT fk_audit_logs_organization FOREIGN KEY (organization_id) REFERENCES organizations (id),
    CONSTRAINT fk_audit_logs_actor FOREIGN KEY (actor_id) REFERENCES users (id) ON DELETE SET NULL
);

CREATE INDEX ix_audit_logs_entity ON audit_logs (entity_type, entity_id);
CREATE INDEX ix_audit_logs_actor_id ON audit_logs (actor_id);
CREATE INDEX ix_audit_logs_created_at ON audit_logs (created_at);
