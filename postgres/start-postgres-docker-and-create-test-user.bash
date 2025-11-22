#!/bin/bash

# Start Docker containers, initialize database, and create test user
cd docker && docker-compose up -d && cd .. && \
docker exec -i postgres-db psql -U postgres -d backlog-manager-db < postgres/backlogmanagerdb-init.sql && \
docker exec -it postgres-db psql -U postgres -d backlog-manager-db -c "
SET search_path = 'blm-system', public;
INSERT INTO \"blm-system\".\"Users\" (\"UserID\", \"Username\", \"Email\", \"PasswordHash\")
VALUES (1, 'test', 'test@test.com', 'dummy_hash')
ON CONFLICT (\"UserID\") DO NOTHING;
SELECT \"UserID\", \"Username\", \"Email\" FROM \"blm-system\".\"Users\" WHERE \"UserID\" = 1;
"