#!/bin/bash

# Initialize the schema and create a test user against the local Postgres
# container. Run `task db:up` first to start that container (it doesn't
# auto-apply this SQL on startup) - this script just seeds it afterward,
# and is safe to re-run any time you need to reset back to this state.
podman exec -i postgres-db psql -U postgres -d backlog-manager-db < postgres/backlogmanagerdb-init.sql && \
podman exec -it postgres-db psql -U postgres -d backlog-manager-db -c "
SET search_path = 'blm-system', public;
INSERT INTO \"blm-system\".\"Users\" (\"UserID\", \"Username\", \"Email\", \"PasswordHash\")
VALUES (1, 'test', 'test@test.com', 'dummy_hash')
ON CONFLICT (\"UserID\") DO NOTHING;
SELECT \"UserID\", \"Username\", \"Email\" FROM \"blm-system\".\"Users\" WHERE \"UserID\" = 1;
"
