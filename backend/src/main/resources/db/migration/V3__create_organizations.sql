-- V3: organizations.
--
-- The first release has a single default organization. Users and tasks
-- still carry an organization_id, so that several organizations (with
-- their own managers and workers) can be added later without reshaping
-- the data.

CREATE TABLE organizations (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name       VARCHAR(150) NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);

INSERT INTO organizations (id, name)
VALUES ('00000000-0000-0000-0000-000000000001', 'Default organization');
