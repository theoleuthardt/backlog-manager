#!/usr/bin/env bash
# Backup of the production database, run on the homelab host (podman) next to
# deploy.sh, which calls it before every deployment. It dumps the database in
# the custom format into one file, checks that the whole archive can be read
# (a restore script written to /dev/null, which reads every data entry, not only
# the table of contents) and only then keeps it: a failed or broken dump is removed and the script
# fails, so a deployment never goes on with a backup it cannot restore from.
# After a good dump it prunes the directory: the newest BLM_BACKUP_KEEP_LATEST
# dumps (14) stay, and the newest dump of each of the last BLM_BACKUP_KEEP_WEEKS
# weeks (8). Only files named blm-YYYYMMDD-HHMMSS.dump are ever removed.
# Settings (environment): BLM_BACKUP_DIR (~/blm-backups), BLM_DB_CONTAINER
# (blm_db), BLM_DB_USER (blm), BLM_DB_NAME (backlog-manager-db),
# BLM_BACKUP_VERIFY=0 skips the archive check.
set -euo pipefail

dir="${BLM_BACKUP_DIR:-$HOME/blm-backups}"
container="${BLM_DB_CONTAINER:-blm_db}"
user="${BLM_DB_USER:-blm}"
database="${BLM_DB_NAME:-backlog-manager-db}"
keep_latest="${BLM_BACKUP_KEEP_LATEST:-14}"
keep_weeks="${BLM_BACKUP_KEEP_WEEKS:-8}"

fail() {
  echo "backup: $*" >&2
  exit 1
}

mkdir -p "$dir"
stamp="${BLM_BACKUP_STAMP:-$(date +%Y%m%d-%H%M%S)}"
final="$dir/blm-$stamp.dump"
partial="$final.partial"
trap 'rm -f "$partial"' EXIT

podman exec "$container" pg_dump -U "$user" -d "$database" -Fc > "$partial" \
  || fail "pg_dump failed, no backup was made"
[ -s "$partial" ] || fail "the dump is empty, no backup was made"
if [ "${BLM_BACKUP_VERIFY:-1}" != 0 ]; then
  podman exec -i "$container" pg_restore --file=/dev/null < "$partial" \
    || fail "the dump is not readable as an archive, no backup was made"
fi
[ ! -e "$final" ] || fail "a backup named $(basename "$final") already exists, nothing was replaced"
mv -n "$partial" "$final"

mapfile -t dumps < <(find "$dir" -maxdepth 1 -name 'blm-????????-??????.dump' -printf '%f\n' | sort -r)
cutoff=$(date -d "${BLM_BACKUP_NOW:-now} $keep_weeks weeks ago" +%Y%m%d)
declare -A week_kept=()
position=0
for dump in "${dumps[@]}"; do
  [[ "$dump" =~ ^blm-[0-9]{8}-[0-9]{6}\.dump$ ]] || continue
  position=$((position + 1))
  day="${dump:4:8}"
  week=$(date -d "${day:0:4}-${day:4:2}-${day:6:2}" +%G-%V)
  keep=0
  if [ "$position" -le "$keep_latest" ]; then
    keep=1
  elif [ "$day" -ge "$cutoff" ] && [ -z "${week_kept[$week]:-}" ]; then
    keep=1
  fi
  if [ "$keep" = 1 ]; then
    week_kept[$week]=1
  else
    rm -f "$dir/$dump"
    echo "backup: removed $dump"
  fi
done

ls -lh "$dir"
