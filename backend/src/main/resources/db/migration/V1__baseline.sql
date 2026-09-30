-- V1: baseline of the TaskInspect database.
--
-- Every change to the schema is a new, numbered migration in this folder
-- (V2__..., V3__...). Migrations are applied in order by Flyway when the
-- backend starts and are never edited after they have been committed.
--
-- The first tables (roles, users) are added in V2 onwards.

COMMENT ON SCHEMA public IS 'TaskInspect application schema, managed by Flyway';
