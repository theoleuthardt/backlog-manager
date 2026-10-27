#!/bin/bash
# Creates the Monitor's own role and database in the local Postgres container
# (`task db:up` first). Safe to re-run: an existing database is left as it is,
# and the role gets the current password, so a changed MONITOR_DB_PASSWORD
# takes effect. The values come from the environment (MONITOR_DB_NAME,
# MONITOR_DB_USER, MONITOR_DB_PASSWORD, POSTGRES_USER); `task monitor:db:create`
# loads them from the root .env, the same way `task monitor:dev` does, so both
# read the same values. MONITOR_DB_CONTAINER names the container (postgres-db
# by default).
set -euo pipefail

: "${POSTGRES_USER:=postgres}"
: "${MONITOR_DB_NAME:=monitor}"
: "${MONITOR_DB_USER:=monitor}"
: "${MONITOR_DB_CONTAINER:=postgres-db}"
[ -n "${MONITOR_DB_PASSWORD:-}" ] || { echo "MONITOR_DB_PASSWORD is not set (see .env.example)" >&2; exit 1; }
if [ "$MONITOR_DB_USER" = "$POSTGRES_USER" ]; then
  echo "MONITOR_DB_USER must differ from POSTGRES_USER, the Monitor gets a role of its own" >&2
  exit 1
fi

for attempt in $(seq 1 30); do
  podman exec "$MONITOR_DB_CONTAINER" pg_isready -q -U "$POSTGRES_USER" && break
  [ "$attempt" -lt 30 ] || { echo "Postgres in \"$MONITOR_DB_CONTAINER\" is not ready after 30 s (task db:up?)" >&2; exit 1; }
  sleep 1
done

podman exec -i "$MONITOR_DB_CONTAINER" psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres \
  -v db="$MONITOR_DB_NAME" -v role="$MONITOR_DB_USER" -v password="$MONITOR_DB_PASSWORD" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'role', :'password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'role') \gexec
SELECT format('ALTER ROLE %I PASSWORD %L', :'role', :'password') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'db', :'role')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db') \gexec
SQL
owner=$(podman exec -i "$MONITOR_DB_CONTAINER" psql -v ON_ERROR_STOP=1 -tA -U "$POSTGRES_USER" -d postgres \
  -v db="$MONITOR_DB_NAME" <<'SQL'
SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = :'db';
SQL
)
if [ "$owner" != "$MONITOR_DB_USER" ]; then
  echo "database \"$MONITOR_DB_NAME\" belongs to \"$owner\", not to \"$MONITOR_DB_USER\"; choose another MONITOR_DB_NAME" >&2
  exit 1
fi
echo "monitor database \"$MONITOR_DB_NAME\" with role \"$MONITOR_DB_USER\" is ready"
