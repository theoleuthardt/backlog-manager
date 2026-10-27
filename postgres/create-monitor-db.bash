#!/bin/bash
# Creates the Monitor's own role and database in the local Postgres container
# (`task db:up` first). Safe to re-run: existing roles and databases are left
# as they are. The values come from the environment or the root .env
# (MONITOR_DB_NAME, MONITOR_DB_USER, MONITOR_DB_PASSWORD, POSTGRES_USER), the
# environment taking precedence; MONITOR_DB_CONTAINER names the container
# (postgres-db by default).
set -euo pipefail

cd "$(dirname "$0")/.."
names=(POSTGRES_USER MONITOR_DB_NAME MONITOR_DB_USER MONITOR_DB_PASSWORD MONITOR_DB_CONTAINER)
declare -A given=()
for name in "${names[@]}"; do
  if [ -n "${!name+x}" ]; then given[$name]=${!name}; fi
done
if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi
for name in "${!given[@]}"; do
  printf -v "$name" '%s' "${given[$name]}"
done

: "${POSTGRES_USER:=postgres}"
: "${MONITOR_DB_NAME:=monitor}"
: "${MONITOR_DB_USER:=monitor}"
: "${MONITOR_DB_CONTAINER:=postgres-db}"
[ -n "${MONITOR_DB_PASSWORD:-}" ] || { echo "MONITOR_DB_PASSWORD is not set (see .env.example)" >&2; exit 1; }

podman exec -i "$MONITOR_DB_CONTAINER" psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres \
  -v db="$MONITOR_DB_NAME" -v role="$MONITOR_DB_USER" -v password="$MONITOR_DB_PASSWORD" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'role', :'password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'role') \gexec
SELECT format('CREATE DATABASE %I OWNER %I', :'db', :'role')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db') \gexec
SQL
echo "monitor database \"$MONITOR_DB_NAME\" with role \"$MONITOR_DB_USER\" is ready"
