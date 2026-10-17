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
[ "$1" = compose ] && echo "BACKEND_IMAGE=$BACKEND_IMAGE XDG=$XDG_RUNTIME_DIR" >> "$FAKE_DIR/calls"
case "$1" in
  pull) exit 0 ;;
  tag) exit 0 ;;
  image)
    case "$2" in
      inspect) echo "$(cat "$state/new-id")" ;;
      list) [ -e "$state/images" ] && cat "$state/images" ;;
      prune) exit 0 ;;
    esac ;;
  rmi)
    [ -e "$state/rmi-fails" ] && exit 1
    exit 0 ;;
  inspect)
    format="$3"; name="$4"
    if [ "$format" = "{{.State.Running}}" ]; then
      [ -e "$state/running-$name" ] && echo true || echo false
    else
      [ -e "$state/image-id" ] && cat "$state/image-id" || exit 1
    fi ;;
  rm)
    if [ -e "$state/rm-fails" ]; then echo "Error: cannot remove blm_backend: container is busy" >&2; exit 125; fi
    if [ -e "$state/rm-partial" ]; then
      left=$(cat "$state/rm-partial")
      if [ "$left" -gt 0 ]; then
        echo $((left - 1)) > "$state/rm-partial"
        for name in blm_price-check-cron blm_steam-wishlist-sync-cron blm_backend; do
          if [ -e "$state/running-$name" ]; then rm -f "$state/running-$name"; break; fi
        done
        echo "Error: cleaning up container: removing container network: netavark: open container netns: No such file or directory" >&2
        exit 125
      fi
    fi
    rm -f "$state/running-blm_backend" "$state/running-blm_price-check-cron" "$state/running-blm_steam-wishlist-sync-cron"; rm -f "$state/image-id" ;;
  container)
    if [ -e "$state/exists-fails" ]; then echo "Error: cannot read the container storage" >&2; exit 125; fi
    [ "$2" = exists ] && [ -e "$state/running-$3" ] && exit 0
    exit 1 ;;
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
      *127.0.0.1:8000/api/auth/login*) [ -e "$state/smoke-fails" ] && exit 1 || exit 0 ;;
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
  writeFileSync(
    join(bin, "loginctl"),
    `#!/usr/bin/env bash\n[ -e "${state}/linger-off" ] && echo no || echo yes\n`,
  );
  chmodSync(join(bin, "loginctl"), 0o755);
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

function startStack(env) {
  for (const name of ["blm_backend", "blm_price-check-cron", "blm_steam-wishlist-sync-cron"]) {
    writeFileSync(join(env.state, `running-${name}`), "");
  }
  writeFileSync(join(env.state, "image-id"), "sha256:old");
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
    assert.match(result.calls, /rm --force --time 10 --depend --ignore blm_backend/);
    assert.doesNotMatch(result.calls, /rm .*blm_db/);
    assert.match(result.calls, /up -d --no-deps --no-recreate backend price-check-cron steam-wishlist-sync-cron/);
    assert.ok(existsSync(join(env.dir, "calls-backup")), "backup ran");
  });

  it("hands compose a constant image name so the config hash does not change per deploy", () => {
    const first = run(env, [SHA]);
    assert.equal(first.status, 0, first.stderr);
    assert.match(first.calls, new RegExp(`tag ${REPO}:${SHA} localhost/backlog-manager-backend:deployed`));
    assert.match(first.calls, /BACKEND_IMAGE=localhost\/backlog-manager-backend:deployed/);
    assert.doesNotMatch(first.calls, new RegExp(`BACKEND_IMAGE=${REPO}`));
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
    assert.equal(existsSync(join(env.dir, "calls-backup")), false, "no backup for a no-op");
  });

  it("aborts before changing anything when the backup fails", () => {
    writeFileSync(join(env.server, "backup.sh"), "#!/usr/bin/env bash\nexit 3\n");
    const result = run(env);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /backup failed/);
    assert.doesNotMatch(result.calls, /compose|rm /);
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

  it("stops and shows the podman error when the old backend cannot be removed", () => {
    startStack(env);
    writeFileSync(join(env.state, "rm-fails"), "");
    const result = run(env);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /cannot remove blm_backend: container is busy/);
    assert.match(result.stderr, /could not remove blm_backend/);
    assert.doesNotMatch(result.calls, /compose/);
    const attempts = result.calls
      .split("\n")
      .filter((line) => line === "rm --force --time 10 --depend --ignore blm_backend");
    assert.equal(attempts.length, 6);
  });

  it("repeats the removal until every container is gone, as podman stops at a network cleanup error", () => {
    startStack(env);
    writeFileSync(join(env.state, "rm-partial"), "3");
    const result = run(env);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /is live/);
    assert.match(result.stderr, /removing blm_backend reported an error \(attempt 1\)/);
    const attempts = result.calls
      .split("\n")
      .filter((line) => line === "rm --force --time 10 --depend --ignore blm_backend");
    assert.equal(attempts.length, 3);
  });

  it("does not take an error of the existence check for a removed container", () => {
    startStack(env);
    writeFileSync(join(env.state, "exists-fails"), "");
    const result = run(env);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /could not remove blm_backend/);
    assert.doesNotMatch(result.calls, /compose/);
  });

  it("does not repeat the removal when it worked at once", () => {
    startStack(env);
    const result = run(env);
    assert.equal(result.status, 0, result.stderr);
    const attempts = result.calls
      .split("\n")
      .filter((line) => line === "rm --force --time 10 --depend --ignore blm_backend");
    assert.equal(attempts.length, 1);
  });

  it("warns when lingering is off but goes on", () => {
    writeFileSync(join(env.state, "linger-off"), "");
    const result = run(env);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stderr, /loginctl enable-linger/);
  });

  it("does not warn when lingering is on", () => {
    const result = run(env);
    assert.doesNotMatch(result.stderr, /enable-linger/);
  });

  it("gives podman the runtime directory of the user when the session has none", () => {
    const result = run(env);
    assert.match(result.calls, new RegExp(`XDG=/run/user/${process.getuid()}`));
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

  it("removes the backend images it no longer needs and keeps the deployed and the previous one", () => {
    writeFileSync(join(env.server, ".deployed-image"), `${REPO}:previous\n`);
    writeFileSync(
      join(env.state, "images"),
      [`${REPO}:old-one`, `${REPO}:previous`, `${REPO}:${SHA}`, `${REPO}:old-two`].join("\n") + "\n",
    );
    const result = run(env);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.calls, new RegExp(`rmi ${REPO}:old-one`));
    assert.match(result.calls, new RegExp(`rmi ${REPO}:old-two`));
    assert.doesNotMatch(result.calls, new RegExp(`rmi ${REPO}:previous`));
    assert.doesNotMatch(result.calls, new RegExp(`rmi ${REPO}:${SHA}`));
    assert.match(result.calls, /image prune/);
  });

  it("leaves the images of another repository that only starts with the same name alone", () => {
    writeFileSync(
      join(env.state, "images"),
      [`${REPO}:old-one`, `${REPO}-staging:old`, `${REPO}x:old`].join("\n") + "\n",
    );
    const result = run(env);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.calls, new RegExp(`rmi ${REPO}:old-one`));
    assert.doesNotMatch(result.calls, /rmi [^\n]*-staging/);
    assert.doesNotMatch(result.calls, new RegExp(`rmi ${REPO}x`));
  });

  it("does not fail the deployment when an old image cannot be removed", () => {
    writeFileSync(join(env.state, "images"), `${REPO}:old-one\n`);
    writeFileSync(join(env.state, "rmi-fails"), "");
    const result = run(env);
    assert.equal(result.status, 0, result.stderr);
  });

  it("does not clean up images after a failed deployment", () => {
    writeFileSync(join(env.state, "images"), `${REPO}:old-one\n`);
    writeFileSync(join(env.state, "unhealthy"), "");
    const result = run(env);
    assert.equal(result.status, 1);
    assert.doesNotMatch(result.calls, /rmi /);
  });

  it("asks the backend for a login with wrong credentials, which it must answer with a 401", () => {
    const result = run(env);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.calls, /exec blm_backend python -c [\s\S]*api\/auth\/login/);
    assert.match(result.stdout, /functional check passed/);
  });

  it("fails the deployment when the functional check fails", () => {
    writeFileSync(join(env.state, "smoke-fails"), "");
    const result = run(env);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /functional check failed/);
    assert.equal(existsSync(join(env.server, ".deployed-image")), false);
  });

  it("takes the backup after the pull, so a no-op costs none, and still aborts before a change when it fails", () => {
    writeFileSync(join(env.server, "backup.sh"), "#!/usr/bin/env bash\nexit 3\n");
    const result = run(env);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /backup failed/);
    assert.doesNotMatch(result.calls, /compose|rm /);
    assert.match(result.calls, /pull /);
  });

  it("redeploys the running image when the request starts with force", () => {
    startStack(env);
    writeFileSync(join(env.state, "image-id"), "sha256:new");
    const result = run(env, [], { SSH_ORIGINAL_COMMAND: `deploy force ${SHA}` });
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.calls, /compose/);
    assert.match(result.stdout, /is live/);
    assert.doesNotMatch(result.stdout, /already running/);
  });

  it("does not force a deployment that was not asked to be forced", () => {
    startStack(env);
    writeFileSync(join(env.state, "image-id"), "sha256:new");
    const result = run(env, [], { SSH_ORIGINAL_COMMAND: `deploy ${SHA}` });
    assert.match(result.stdout, /already running/);
  });

  it("refuses words before the image other than deploy and force", () => {
    for (const bad of [`deploy rm ${SHA}`, `deploy forced ${SHA}`, `force deploy force --x ${SHA}`]) {
      const result = run(env, [], { SSH_ORIGINAL_COMMAND: bad });
      assert.notEqual(result.status, 0, bad);
      assert.match(result.stderr, /refusing/, bad);
      assert.equal(result.calls, "", `${bad} must not reach podman`);
    }
  });

  it("does not let a glob in the request stand for a word that a file name would spell", () => {
    writeFileSync(join(env.server, "force"), "");
    const result = run(env, [], { SSH_ORIGINAL_COMMAND: `deploy f* ${SHA}` });
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /refusing/);
    assert.equal(result.calls, "");
  });
});

