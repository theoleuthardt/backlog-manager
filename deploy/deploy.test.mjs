import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { beforeEach, describe, it } from "node:test";
import { fileURLToPath } from "node:url";

const deployScript = fileURLToPath(new URL("./deploy.sh", import.meta.url));
const REPO = "ghcr.io/theoleuthardt/backlog-manager-backend";
const SHA = "0123456789abcdef0123456789abcdef01234567";

const FAKE_PODMAN = `#!/usr/bin/env bash
state="$FAKE_DIR/state"
echo "$*" >> "$FAKE_DIR/calls"
case "$1" in
  pull) exit 0 ;;
  image) echo "$(cat "$state/new-id")" ;;
  inspect)
    format="$3"; name="$4"
    if [ "$format" = "{{.State.Running}}" ]; then
      [ -e "$state/running-$name" ] && echo true || echo false
    else
      [ -e "$state/image-id" ] && cat "$state/image-id" || exit 1
    fi ;;
  rm) rm -f "$state/running-blm_backend" "$state/running-blm_price-check-cron" "$state/running-blm_steam-wishlist-sync-cron"; rm -f "$state/image-id" ;;
  compose)
    if [ -e "$state/compose-fails-silently" ]; then exit 0; fi
    touch "$state/running-blm_backend" "$state/running-blm_price-check-cron" "$state/running-blm_steam-wishlist-sync-cron"
    cp "$state/new-id" "$state/image-id"
    [ -e "$state/compose-exits-nonzero" ] && exit 1
    exit 0 ;;
  exec)
    case "$*" in
      *alembic*) [ -e "$state/not-at-head" ] && echo "abc123" || echo "abc123 (head)" ;;
      *127.0.0.1:8000/health\\'*) [ -e "$state/unhealthy" ] && exit 1 || exit 0 ;;
      *) exit 1 ;;
    esac ;;
  logs) echo "backend log line" ;;
esac
`;

function setup() {
  const dir = mkdtempSync(join(tmpdir(), "blm-deploy-"));
  const bin = join(dir, "bin");
  const state = join(dir, "state");
  const server = join(dir, "server");
  for (const d of [bin, state, server]) mkdirSync(d);
  writeFileSync(join(bin, "podman"), FAKE_PODMAN);
  chmodSync(join(bin, "podman"), 0o755);
  copyFileSync(deployScript, join(server, "deploy.sh"));
  chmodSync(join(server, "deploy.sh"), 0o755);
  writeFileSync(join(server, "compose.prod.yml"), "services: {}\n");
  writeFileSync(join(server, "backup.sh"), `#!/usr/bin/env bash\necho backup >> "${dir}/calls-backup"\n`);
  chmodSync(join(server, "backup.sh"), 0o755);
  writeFileSync(join(state, "running-blm_db"), "");
  writeFileSync(join(state, "new-id"), "sha256:new");
  return { dir, bin, state, server };
}

function run(env, args = [SHA], extraEnv = {}) {
  const result = spawnSync(join(env.server, "deploy.sh"), args, {
    encoding: "utf8",
    env: {
      PATH: `${env.bin}:${process.env.PATH}`,
      FAKE_DIR: env.dir,
      BLM_HEALTH_TIMEOUT: "1",
      BLM_HEALTH_INTERVAL: "1",
      ...extraEnv,
    },
  });
  const calls = existsSync(join(env.dir, "calls")) ? readFileSync(join(env.dir, "calls"), "utf8") : "";
  return { ...result, calls };
}

describe("deploy.sh", () => {
  let env;
  beforeEach(() => {
    env = setup();
  });

  it("deploys a full git SHA as the image tag, records it and never touches the database", () => {
    const result = run(env);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /is live/);
    assert.equal(readFileSync(join(env.server, ".deployed-image"), "utf8").trim(), `${REPO}:${SHA}`);
    assert.match(result.calls, new RegExp(`pull ${REPO}:${SHA}`));
    assert.match(result.calls, /rm --force --depend --ignore blm_backend/);
    assert.doesNotMatch(result.calls, /rm .*blm_db/);
    assert.match(result.calls, /up -d --no-deps backend price-check-cron steam-wishlist-sync-cron/);
    assert.ok(existsSync(join(env.dir, "calls-backup")), "backup ran");
  });

  it("takes the image from SSH_ORIGINAL_COMMAND and uses its last word", () => {
    const result = run(env, [], { SSH_ORIGINAL_COMMAND: `deploy ${SHA}` });
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.calls, new RegExp(`pull ${REPO}:${SHA}`));
  });

  it("refuses images outside the backend repository and malformed refs", () => {
    for (const bad of [
      "ghcr.io/someone/else:latest",
      `${REPO}:bad tag`,
      `${REPO}:$(touch pwned)`,
      `${REPO}@sha256:123`,
      "latest; rm -rf /",
      "",
    ]) {
      const result = run(env, [bad]);
      assert.notEqual(result.status, 0, bad);
      assert.equal(result.calls, "", `${bad} must not reach podman`);
    }
  });

  it("does nothing when the requested image already runs", () => {
    writeFileSync(join(env.state, "running-blm_backend"), "");
    writeFileSync(join(env.state, "image-id"), "sha256:new");
    const result = run(env);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /already running/);
    assert.doesNotMatch(result.calls, /compose/);
  });

  it("aborts before changing anything when the backup fails", () => {
    writeFileSync(join(env.server, "backup.sh"), "#!/usr/bin/env bash\nexit 3\n");
    const result = run(env);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /backup failed/);
    assert.doesNotMatch(result.calls, /pull|compose|rm /);
  });

  it("aborts when the backup script is missing", () => {
    const result = run(env, [SHA], { BLM_BACKUP_SCRIPT: "./missing.sh" });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /backup script/);
    assert.doesNotMatch(result.calls, /compose/);
  });

  it("aborts when the database container is not running", () => {
    spawnSync("rm", [join(env.state, "running-blm_db")]);
    const result = run(env);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /blm_db is not running/);
    assert.doesNotMatch(result.calls, /compose|rm /);
  });

  it("trusts the containers, not the exit code of compose up", () => {
    writeFileSync(join(env.state, "compose-exits-nonzero"), "");
    const result = run(env);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /verifying the containers/);
  });

  it("fails and keeps the previous image on record when the backend is unhealthy", () => {
    writeFileSync(join(env.server, ".deployed-image"), `${REPO}:previous\n`);
    writeFileSync(join(env.state, "unhealthy"), "");
    const result = run(env);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /did not become healthy/);
    assert.match(result.stderr, new RegExp(`Previous image: ${REPO}:previous`));
    assert.equal(readFileSync(join(env.server, ".deployed-image"), "utf8").trim(), `${REPO}:previous`);
  });

  it("fails when the database is not at the Alembic head", () => {
    writeFileSync(join(env.state, "not-at-head"), "");
    const result = run(env);
    assert.equal(result.status, 1);
  });

  it("fails when the containers did not start", () => {
    writeFileSync(join(env.state, "compose-fails-silently"), "");
    const result = run(env);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /is not running/);
  });

  it("remembers the replaced image as the previous one after a successful deploy", () => {
    writeFileSync(join(env.server, ".deployed-image"), `${REPO}:old\n`);
    const result = run(env);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(readFileSync(join(env.server, ".previous-image"), "utf8").trim(), `${REPO}:old`);
  });
});
