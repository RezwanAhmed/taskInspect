-- V13: operations from the app's sync queue that the server has applied
-- (POST /api/sync/push, see docs/architecture.md "Sync Cycle").
--
-- The ID is created on the device. When the same operation arrives again,
-- for example because the answer to the first push was lost, the server
-- finds it here and does not apply it twice. Refused operations are not
-- recorded, so the app can send them again after the problem is fixed.

CREATE TABLE sync_records (
    id          UUID        PRIMARY KEY,
    user_id     UUID        NOT NULL,
    task_id     UUID        NOT NULL,
    entity_type VARCHAR(30) NOT NULL,
    entity_id   UUID        NOT NULL,
    operation   VARCHAR(20) NOT NULL,
    applied_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_sync_records_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_sync_records_task FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
    CONSTRAINT ck_sync_records_entity_type CHECK (entity_type IN ('Task', 'TaskResponse', 'Evidence')),
    CONSTRAINT ck_sync_records_operation
        CHECK (operation IN ('CREATE', 'UPDATE', 'DELETE', 'START', 'SUBMIT'))
);

CREATE INDEX ix_sync_records_user_id ON sync_records (user_id);
CREATE INDEX ix_sync_records_task_id ON sync_records (task_id);
