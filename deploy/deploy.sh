#!/usr/bin/env bash
# Production deployment of the backend on the homelab host (podman with
# podman-compose). Installed next to compose.prod.yml, normally run through the
# forced command of the deploy SSH key (docs/DEPLOYMENT.md) with the image as
# argument or as SSH_ORIGINAL_COMMAND: a full git SHA of this repository's
# backend image, or an explicit ghcr.io/theoleuthardt/backlog-manager-backend
# tag or digest. Order: validate, database must run, backup, pull, replace only
# the backend and the two cron containers (never the database), verify the
# containers, health and Alembic head. A failed deploy does not roll back on its
# own: the new code may already have migrated the schema and an older image
# cannot start on an Alembic revision it does not know; it prints the previous
# image and the backup instead. podman-compose 1.x tries to create the database
# container again on `up` and reports an error although the service started, so
# the result of `up` is not trusted and the containers are verified instead.
set -euo pipefail

cd "$(dirname "$0")"

image_repo="ghcr.io/theoleuthardt/backlog-manager-backend"
backup_script="${BLM_BACKUP_SCRIPT:-./backup.sh}"
health_timeout="${BLM_HEALTH_TIMEOUT:-120}"
health_interval="${BLM_HEALTH_INTERVAL:-3}"
services=(blm_backend blm_price-check-cron blm_steam-wishlist-sync-cron)

fail() {
  echo "deploy: $*" >&2
  exit 1
}

request="${1:-${SSH_ORIGINAL_COMMAND:-}}"
ref="${request##* }"
if [[ "$ref" =~ ^[0-9a-f]{40}$ ]]; then
  ref="$image_repo:$ref"
fi
tag_pattern='^[A-Za-z0-9._-]{1,128}$'
digest_pattern='^[0-9a-f]{64}$'
valid=0
if [[ "$ref" == "$image_repo:"* && "${ref#"$image_repo":}" =~ $tag_pattern ]]; then valid=1; fi
if [[ "$ref" == "$image_repo@sha256:"* && "${ref#"$image_repo"@sha256:}" =~ $digest_pattern ]]; then valid=1; fi
[ "$valid" = 1 ] || fail "refusing image '$ref': expected a git SHA, or a tag or digest of $image_repo"

exec 9>.deploy.lock
flock -n 9 || fail "another deployment is running"

[ -f compose.prod.yml ] || fail "compose.prod.yml not found in $PWD"
[ -x "$backup_script" ] || fail "backup script $backup_script is missing or not executable"

running() {
  [ "$(podman inspect --format '{{.State.Running}}' "$1" 2>/dev/null || true)" = true ]
}

running blm_db || fail "the database container blm_db is not running, not touching anything"

echo "deploy: backing up the database"
"$backup_script" || fail "backup failed, nothing was changed"

echo "deploy: pulling $ref"
podman pull "$ref" >/dev/null
new_id=$(podman image inspect --format '{{.Id}}' "$ref")
current_id=$(podman inspect --format '{{.Image}}' blm_backend 2>/dev/null || true)
if [ "$new_id" = "$current_id" ] && [ "${BLM_FORCE:-0}" != 1 ] && running blm_backend; then
  echo "deploy: $ref is already running, nothing to do"
  exit 0
fi

previous=$(cat .deployed-image 2>/dev/null || true)

echo "deploy: replacing the backend and the cron containers"
podman rm --force --depend --ignore blm_backend >/dev/null 2>&1 || true
podman rm --force --depend --ignore blm_backend-old >/dev/null 2>&1 || true
BACKEND_IMAGE="$ref" podman compose -f compose.prod.yml up -d --no-deps \
  backend price-check-cron steam-wishlist-sync-cron \
  || echo "deploy: compose reported errors, verifying the containers instead"

healthy=0
for service in "${services[@]}"; do
  running "$service" || { echo "deploy: $service is not running" >&2; healthy=1; }
done
if [ "$healthy" = 0 ]; then
  [ "$(podman inspect --format '{{.Image}}' blm_backend)" = "$new_id" ] \
    || { echo "deploy: blm_backend does not run $ref" >&2; healthy=1; }
fi

waited=0
[ "$healthy" != 0 ] || echo "deploy: waiting for the backend (up to ${health_timeout}s)"
while [ "$healthy" = 0 ]; do
  if podman exec blm_backend python -c \
      "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=3)" \
      >/dev/null 2>&1 \
    && podman exec blm_backend alembic current 2>/dev/null | grep -q '(head)'; then
    break
  fi
  if [ "$waited" -ge "$health_timeout" ]; then
    echo "deploy: the backend did not become healthy within ${health_timeout}s" >&2
    healthy=1
    break
  fi
  sleep "$health_interval"
  waited=$((waited + health_interval))
done

if [ "$healthy" != 0 ]; then
  podman logs --tail 50 blm_backend >&2 || true
  echo "deploy: FAILED. Previous image: ${previous:-unknown}. The pre-deploy backup is the newest dump in the backup directory." >&2
  exit 1
fi

[ -z "$previous" ] || echo "$previous" > .previous-image
echo "$ref" > .deployed-image
echo "deploy: $ref is live"
