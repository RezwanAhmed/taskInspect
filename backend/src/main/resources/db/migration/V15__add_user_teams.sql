-- V15: teams (Phase 7A, docs/architecture.md "Teams").
--
-- Every worker belongs to at most one manager's team: team_manager_id is
-- that manager (NULL: no team). Removing a manager leaves their workers
-- without a team.

ALTER TABLE users ADD COLUMN team_manager_id UUID;

ALTER TABLE users ADD CONSTRAINT fk_users_team_manager
    FOREIGN KEY (team_manager_id) REFERENCES users (id) ON DELETE SET NULL;

ALTER TABLE users ADD CONSTRAINT ck_users_team_manager_not_self
    CHECK (team_manager_id IS NULL OR team_manager_id <> id);

CREATE INDEX ix_users_team_manager_id ON users (team_manager_id);
