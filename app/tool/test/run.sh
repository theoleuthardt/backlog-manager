#!/usr/bin/env bash
# Runs the app's tests as the only test run (a lock refuses a second one), in
# its own process group with a time limit, and kills the group afterwards, so
# a hung test cannot leave flutter_tester processes behind. Arguments are
# passed to flutter test.
#
# The suite runs as one `flutter test` with one worker per core
# (TEST_CONCURRENCY). Without test files in the arguments the tests of every
# file except the golden ones run in as many bundles as there are workers
# (TEST_BUNDLES, tool/test/bundles.dart): `flutter test` starts a process per
# file and each pays its warm-up, a bundle pays it once. TEST_BUNDLES=0 runs
# every file on its own, as `flutter test` does (TEST_SHARD=1 does so too). A run without `--tags` or
# `--exclude-tags` then runs the golden tests from their own files. On a
# machine with little memory (the compiler of one run for the whole suite grows
# to 2 GB and more) set TEST_SHARD=1 to run one `flutter test` per test
# directory instead, one worker at a time.
set -u
cd "$(dirname "$0")/../.."

lock="${TMPDIR:-/tmp}/blm-flutter-test.lock.d"
if ! mkdir "$lock" 2>/dev/null; then
  holder=$(cat "$lock/pid" 2>/dev/null)
  if [ -n "$holder" ] && kill -0 "$holder" 2>/dev/null; then
    echo "another flutter test run is active (pid $holder); concurrent runs crash the compiler" >&2
    exit 75
  fi
  stale=$(cat "$lock/group" 2>/dev/null)
  [ -n "$stale" ] && kill -KILL -- "-$stale" 2>/dev/null
  rm -rf "$lock"
  mkdir "$lock"
fi
echo $$ > "$lock/pid"

cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
per_test="${TEST_TIMEOUT:-60s}"
limit="${TEST_RUN_TIMEOUT:-900}"
workers="${TEST_CONCURRENCY:-$cores}"
pid=""

reap() {
  [ -n "$pid" ] && kill -KILL -- "-$pid" 2>/dev/null
  return 0
}
release() {
  reap
  rm -rf "$lock" test/bundles
}
trap release EXIT INT TERM

if command -v setsid >/dev/null 2>&1; then
  new_group=setsid
else
  new_group=
fi

run_flutter() {
  local count="$1"
  shift
  $new_group flutter test --no-pub --timeout="$per_test" --concurrency="$count" "$@" &
  pid=$!
  echo "$pid" > "$lock/group"
  $new_group bash -c 'sleep "$1"; echo "test run exceeded $1s, killing it" >&2; kill -KILL -- "-$2"' _ "$limit" "$pid" &
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
goldens_only=0
filtered=0
previous=""
for arg in "$@"; do
  case "$arg" in
    test/*|*_test.dart) explicit=1 ;;
    --update-goldens|--tags|--tags=*) goldens_only=1 ;;
    --exclude-tags=*golden*) filtered=1 ;;
    *golden*) [ "$previous" = "--exclude-tags" ] && filtered=1 ;;
  esac
  previous="$arg"
done

bundles="${TEST_BUNDLES:-$workers}"

if [ "$explicit" = 1 ]; then
  run_flutter "$workers" "$@"
  exit $?
fi

if [ "$goldens_only" = 0 ] && [ "$bundles" != 0 ] && [ "${TEST_SHARD:-0}" != 1 ]; then
  files=$(dart run tool/test/bundles.dart "$bundles" | grep '^test/') || exit 1
  failed=0
  # shellcheck disable=SC2086
  run_flutter "$workers" --exclude-tags golden "$@" $files || failed=1
  if [ "$filtered" = 0 ]; then
    run_flutter "$workers" --tags golden "$@" || failed=1
  fi
  exit "$failed"
fi

if [ "${TEST_SHARD:-0}" != 1 ]; then
  run_flutter "$workers" "$@"
  exit $?
fi

failed=0
for dir in $(find test -name '*_test.dart' -not -path 'test/bundles/*' -exec dirname {} + | sort -u); do
  files=$(ls "$dir"/*_test.dart)
  echo "== $dir"
  # shellcheck disable=SC2086
  run_flutter 1 "$@" $files || failed=1
done
exit "$failed"
