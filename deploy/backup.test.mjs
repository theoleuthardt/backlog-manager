import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  chmodSync,
  copyFileSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { beforeEach, describe, it } from "node:test";
import { fileURLToPath } from "node:url";

const backupScript = fileURLToPath(new URL("./backup.sh", import.meta.url));

const FAKE_PODMAN = `#!/usr/bin/env bash
state="$FAKE_DIR/state"
echo "$*" >> "$FAKE_DIR/calls"
[ "$1" = exec ] || exit 1
case "$*" in
  *pg_dump*)
    [ -e "$state/dump-fails" ] && { echo "pg_dump: error: connection failed" >&2; exit 1; }
    [ -e "$state/dump-empty" ] && exit 0
    printf 'PGDMP-%s' "$FAKE_STAMP" ;;
  *pg_restore*)
    cat > /dev/null
    [ -e "$state/restore-fails" ] && { echo "pg_restore: error: not a valid archive" >&2; exit 1; }
    exit 0 ;;
esac
`;

function setup() {
  const dir = mkdtempSync(join(tmpdir(), "blm-backup-"));
  const bin = join(dir, "bin");
  const state = join(dir, "state");
  const backups = join(dir, "backups");
  for (const d of [bin, state, backups]) mkdirSync(d);
  writeFileSync(join(bin, "podman"), FAKE_PODMAN);
  chmodSync(join(bin, "podman"), 0o755);
  const server = join(dir, "server");
  mkdirSync(server);
  copyFileSync(backupScript, join(server, "backup.sh"));
  chmodSync(join(server, "backup.sh"), 0o755);
  return { dir, bin, state, backups, server };
}

function run(env, extra = {}) {
  const result = spawnSync(join(env.server, "backup.sh"), [], {
    encoding: "utf8",
    env: {
      PATH: `${env.bin}:${process.env.PATH}`,
      HOME: env.dir,
      FAKE_DIR: env.dir,
      FAKE_STAMP: "20261017-120000",
      BLM_BACKUP_DIR: env.backups,
      BLM_BACKUP_STAMP: "20261017-120000",
      BLM_BACKUP_NOW: "2026-10-17 12:00:00",
      ...extra,
    },
  });
  const calls = existsSync(join(env.dir, "calls")) ? readFileSync(join(env.dir, "calls"), "utf8") : "";
  return { ...result, calls };
}

const names = (env) => readdirSync(env.backups).sort();

describe("backup.sh", () => {
  let env;
  beforeEach(() => {
    env = setup();
  });

  it("writes the dump with the stamp, lists the directory and succeeds", () => {
    const result = run(env);
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(names(env), ["blm-20261017-120000.dump"]);
    assert.equal(readFileSync(join(env.backups, "blm-20261017-120000.dump"), "utf8"), "PGDMP-20261017-120000");
    assert.match(result.stdout, /blm-20261017-120000\.dump/);
  });

  it("dumps the configured database of the configured container with the custom format", () => {
    const result = run(env, { BLM_DB_USER: "u", BLM_DB_NAME: "d", BLM_DB_CONTAINER: "c" });
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.calls, /exec c pg_dump -U u -d d -Fc/);
  });

  it("fails and leaves no file when pg_dump fails", () => {
    writeFileSync(join(env.backups, "blm-20261016-120000.dump"), "old");
    writeFileSync(join(env.state, "dump-fails"), "");
    const result = run(env);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /pg_dump: error/);
    assert.deepEqual(names(env), ["blm-20261016-120000.dump"]);
  });

  it("fails and removes the file when the dump is empty", () => {
    writeFileSync(join(env.state, "dump-empty"), "");
    const result = run(env);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /empty/);
    assert.deepEqual(names(env), []);
  });

  it("fails and removes the file when the dump is not a readable archive", () => {
    writeFileSync(join(env.state, "restore-fails"), "");
    const result = run(env);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /not readable/);
    assert.deepEqual(names(env), []);
  });

  it("does not prune anything when the new dump failed", () => {
    for (const day of ["20260101", "20260102", "20260103"]) {
      writeFileSync(join(env.backups, `blm-${day}-000000.dump`), "old");
    }
    writeFileSync(join(env.state, "dump-fails"), "");
    run(env, { BLM_BACKUP_KEEP_LATEST: "1", BLM_BACKUP_KEEP_WEEKS: "0" });
    assert.equal(names(env).length, 3);
  });

  describe("retention", () => {
    const dumps = [
      "20261016-120000", // 2nd newest
      "20261015-120000", // same week as the newest, not its newest
      "20261009-100000", // newest of an earlier week inside the window
      "20261008-100000", // same week, older
      "20261002-100000", // older than the window
      "20260101-000000", // far older
    ];

    it("keeps the newest dumps and the newest dump of each week of the window", () => {
      for (const d of dumps) writeFileSync(join(env.backups, `blm-${d}.dump`), "old");
      const result = run(env, { BLM_BACKUP_KEEP_LATEST: "2", BLM_BACKUP_KEEP_WEEKS: "2" });
      assert.equal(result.status, 0, result.stderr);
      assert.deepEqual(names(env), [
        "blm-20261009-100000.dump",
        "blm-20261016-120000.dump",
        "blm-20261017-120000.dump",
      ]);
    });

    it("keeps at least the configured number of newest dumps", () => {
      for (const d of dumps) writeFileSync(join(env.backups, `blm-${d}.dump`), "old");
      run(env, { BLM_BACKUP_KEEP_LATEST: "5", BLM_BACKUP_KEEP_WEEKS: "0" });
      assert.equal(names(env).length, 5);
      assert.ok(names(env).includes("blm-20261017-120000.dump"));
    });

    it("leaves files that are not dumps of this script alone", () => {
      writeFileSync(join(env.backups, "notes.txt"), "keep me");
      writeFileSync(join(env.backups, "blm-20250101-000000.dump.partial"), "x");
      run(env, { BLM_BACKUP_KEEP_LATEST: "1", BLM_BACKUP_KEEP_WEEKS: "0" });
      assert.ok(names(env).includes("notes.txt"));
      assert.ok(names(env).includes("blm-20250101-000000.dump.partial"));
    });
  });
});
