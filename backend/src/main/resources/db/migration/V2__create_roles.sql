-- V2: roles that can be given to users.
--
-- The first release has three roles (spec section 3); reviewing is done
-- by managers. A user can have more than one role (for example a solo
-- user is both MANAGER and WORKER).

CREATE TABLE roles (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(50)  NOT NULL,
    description VARCHAR(255) NOT NULL,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uk_roles_name UNIQUE (name),
    CONSTRAINT ck_roles_name CHECK (name IN ('ADMINISTRATOR', 'MANAGER', 'WORKER'))
);

INSERT INTO roles (name, description) VALUES
    ('ADMINISTRATOR', 'Manages users, roles and system settings; can see all tasks'),
    ('MANAGER',       'Creates, assigns and reviews tasks'),
    ('WORKER',        'Executes assigned tasks and submits them for review');
