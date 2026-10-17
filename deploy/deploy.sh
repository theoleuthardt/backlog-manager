#!/usr/bin/env bash
# Production deployment of the backend on the homelab host (podman with
# podman-compose). Installed next to compose.prod.yml, normally run through the
# forced command of the deploy SSH key (docs/DEPLOYMENT.md). The request is the
# argument or SSH_ORIGINAL_COMMAND: a full git SHA of this repository's backend
# image, or an explicit ghcr.io/theoleuthardt/backlog-manager-backend tag or
# digest, optionally after the words `deploy` and `force` (force redeploys the
# image that already runs, for a changed compose file); any other word is
# refused. Order: validate, the database must run, pull, stop when that image
# already runs, backup, replace only the backend and the two cron containers
# (never the database), verify the containers, /health, the Alembic head and a
# functional check, then remove the backend images that are neither the
# deployed nor the previous one. A failed deploy does not roll back on its
# own: the new code may already have migrated the schema and an older image
# cannot start on an Alembic revision it does not know; it prints the previous
# image and the backup instead. podman-compose 1.x tries to create the database
# container again on `up` and reports an error although the service started, so
# the result of `up` is not trusted and the containers are verified instead.
# Removing a container whose network namespace file is gone (it lived in the
# runtime directory of a login session that ended) makes podman report an
# error and stop after the container it was working on, so the removal is
# repeated until each container is really gone; lingering keeps the directory.
# `up` of podman-compose tears every container of the project down when the
# config hash of an existing one differs. 1.3 ignores `--no-deps` when it picks
# those containers, so the database is stopped and recreated (seen in
# production); 1.4 honors it. `--no-recreate` is not implemented in 1.3 and 1.4.
# The image reference is part of the config, so the pulled image is tagged with
# the constant name $local_image and only that name is handed to compose: the
# hash then changes only when compose.prod.yml itself changes. The first deploy
# after switching from per-deploy image names still restarts the database once.
set -euo pipefail

cd "$(dirname "$0")"

image_repo="ghcr.io/theoleuthardt/backlog-manager-backend"
backup_script="${BLM_BACKUP_SCRIPT:-./backup.sh}"
health_timeout="${BLM_HEALTH_TIMEOUT:-120}"
health_interval="${BLM_HEALTH_INTERVAL:-3}"
local_image="localhost/backlog-manager-backend:deployed"
services=(blm_backend blm_price-check-cron blm_steam-wishlist-sync-cron)

fail() {
  echo "deploy: $*" >&2
  exit 1
}

request="${1:-${SSH_ORIGINAL_COMMAND:-}}"
ref="${request##* }"
words="${request% *}"
[ "$words" != "$request" ] || words=""
for word in $words; do
  case "$word" in
    deploy) ;;
    force) BLM_FORCE=1 ;;
    *) fail "refusing the request '$request': only the words deploy and force may come before the image" ;;
  esac
done
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

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if command -v loginctl >/dev/null 2>&1 \
  && [ "$(loginctl show-user "$(id -un)" --property=Linger --value 2>/dev/null || true)" = no ]; then
  echo "deploy: warning: lingering is off for $(id -un), the network namespaces of the containers vanish when the last login session ends and a later removal then reports errors; run 'loginctl enable-linger $(id -un)' once" >&2
fi

[ -f compose.prod.yml ] || fail "compose.prod.yml not found in $PWD"
[ -x "$backup_script" ] || fail "backup script $backup_script is missing or not executable"

remove_container() {
  local name="$1" attempt code
  for attempt in 1 2 3 4 5 6; do
    podman rm --force --time 10 --depend --ignore "$name" \
      || echo "deploy: removing $name reported an error (attempt $attempt), checking whether it is gone" >&2
    code=0
    podman container exists "$name" || code=$?
    [ "$code" -eq 1 ] && return 0
  done
  return 1
}

smoke_check() {
  podman exec blm_backend python -c "import json, sys, urllib.error, urllib.request
request = urllib.request.Request('http://127.0.0.1:8000/api/auth/login', data=json.dumps({'email': 'deploy-check@invalid.example', 'password': 'not-a-real-password'}).encode(), headers={'Content-Type': 'application/json'})
try:
    urllib.request.urlopen(request, timeout=10)
except urllib.error.HTTPError as error:
    sys.exit(0 if error.code == 401 else 1)
sys.exit(1)" > /dev/null 2>&1
}

prune_images() {
  local image kept
  while read -r image; do
    [[ "$image" == "$image_repo:"* ]] || continue
    for kept in "$ref" "$previous"; do
      [ "$image" = "$kept" ] && continue 2
    done
    podman rmi "$image" > /dev/null 2>&1 || true
  done < <(podman image list --filter "reference=$image_repo" --format '{{.Repository}}:{{.Tag}}' 2>/dev/null || true)
  podman image prune --force > /dev/null 2>&1 || true
}

running() {
  [ "$(podman inspect --format '{{.State.Running}}' "$1" 2>/dev/null || true)" = true ]
}

running blm_db || fail "the database container blm_db is not running, not touching anything"

echo "deploy: pulling $ref"
podman pull "$ref" >/dev/null
new_id=$(podman image inspect --format '{{.Id}}' "$ref")
current_id=$(podman inspect --format '{{.Image}}' blm_backend 2>/dev/null || true)
if [ "$new_id" = "$current_id" ] && [ "${BLM_FORCE:-0}" != 1 ] && running blm_backend; then
  echo "deploy: $ref is already running, nothing to do"
  exit 0
fi

echo "deploy: backing up the database"
"$backup_script" || fail "backup failed, nothing was changed"

previous=$(cat .deployed-image 2>/dev/null || true)

echo "deploy: replacing the backend and the cron containers"
for old in blm_backend blm_backend-old; do
  remove_container "$old" \
    || { podman ps -a >&2 || true; fail "could not remove $old (see the podman error above), nothing was started"; }
done
podman tag "$ref" "$local_image"
BACKEND_IMAGE="$local_image" podman compose -f compose.prod.yml up -d --no-deps --no-recreate \
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

if [ "$healthy" = 0 ]; then
  if smoke_check; then
    echo "deploy: functional check passed (a login with wrong credentials is answered with 401)"
  else
    echo "deploy: functional check failed: a login with wrong credentials was not answered with 401" >&2
    healthy=1
  fi
fi

if [ "$healthy" != 0 ]; then
  podman logs --tail 50 blm_backend >&2 || true
  echo "deploy: FAILED. Previous image: ${previous:-unknown}. The pre-deploy backup is the newest dump in the backup directory." >&2
  exit 1
fi

[ -z "$previous" ] || echo "$previous" > .previous-image
echo "$ref" > .deployed-image
prune_images
echo "deploy: $ref is live"
