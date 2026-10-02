-- V19: drafts made offline (Phase 7B): the sync push also changes
-- requirements and their order, so sync_records can name them.

ALTER TABLE sync_records DROP CONSTRAINT ck_sync_records_entity_type;
ALTER TABLE sync_records ADD CONSTRAINT ck_sync_records_entity_type
    CHECK (entity_type IN ('Task', 'TaskResponse', 'Evidence', 'Requirement', 'RequirementOrder'));
