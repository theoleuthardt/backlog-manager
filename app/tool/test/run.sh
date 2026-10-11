#!/usr/bin/env bash
# Runs the app's tests as the only test run (a lock refuses a second one),
# one `flutter test` per test directory so the compiler restarts and stays
# inside the memory of small machines (one run for the whole suite grows past
# 2 GB and gets OOM-killed). Every run has its own process group and a time
# limit and is killed afterwards, so a hung test cannot leave flutter_tester
# processes behind. Arguments are passed to flutter test; with a path under
# test/ only that path runs, as one invocation.
set -u
cd "$(dirname "$0")/../.."

exec 9>"${TMPDIR:-/tmp}/blm-flutter-test.lock"
if ! flock -n 9; then
  echo "another flutter test run is active; concurrent runs crash the compiler" >&2
  exit 75
fi
pkill -KILL -x flutter_tester 2>/dev/null

per_test="${TEST_TIMEOUT:-60s}"
shard_limit="${TEST_SHARD_TIMEOUT:-420}"
pid=""

reap() {
  [ -n "$pid" ] && kill -KILL -- "-$pid" 2>/dev/null
  pkill -KILL -x flutter_tester 2>/dev/null
  return 0
}
trap reap EXIT INT TERM

run_shard() {
  setsid flutter test --timeout="$per_test" --concurrency=1 "$@" 9>&- &
  pid=$!
  setsid bash -c 'sleep "$1"; echo "shard exceeded $1s, killing it" >&2; kill -KILL -- "-$2"' _ "$shard_limit" "$pid" 9>&- &
  local watchdog=$!
  wait "$pid"
  local status=$?
  kill -KILL -- "-$watchdog" 2>/dev/null
  wait "$watchdog" 2>/dev/null
  reap
  pid=""
  return "$status"
}

explicit=0
for arg in "$@"; do
  case "$arg" in test/*|*_test.dart) explicit=1 ;; esac
done

if [ "$explicit" = 1 ]; then
  run_shard "$@"
  exit $?
fi

failed=0
for dir in $(find test -name '*_test.dart' -printf '%h\n' | sort -u); do
  files=$(ls "$dir"/*_test.dart)
  echo "== $dir"
  # shellcheck disable=SC2086
  run_shard "$@" $files || failed=1
done
exit "$failed"
