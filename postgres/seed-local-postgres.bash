#!/bin/bash
set -e

: "${POSTGRES_USER:=postgres}"
: "${POSTGRES_DB:=backlog-manager-db}"

# Initialize the schema and create a test user against the local Postgres
# container. Run `task db:up` first to start that container (it doesn't
# auto-apply this SQL on startup) - this script just seeds it afterward,
# and is safe to re-run any time you need to reset back to this state.
# POSTGRES_USER/POSTGRES_DB default to the same values as .env.example -
# export them beforehand if your .env overrides them.
podman exec -i postgres-db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < postgres/backlogmanagerdb-init.sql && \
podman exec -it postgres-db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "
SET search_path = 'blm-system', public;
INSERT INTO \"blm-system\".\"Users\" (\"UserID\", \"Username\", \"Email\", \"PasswordHash\")
VALUES (1, 'test', 'test@test.com', 'dummy_hash')
ON CONFLICT (\"UserID\") DO UPDATE
SET \"Username\" = EXCLUDED.\"Username\",
    \"Email\" = EXCLUDED.\"Email\",
    \"PasswordHash\" = EXCLUDED.\"PasswordHash\";
SELECT \"UserID\", \"Username\", \"Email\" FROM \"blm-system\".\"Users\" WHERE \"UserID\" = 1;
"
