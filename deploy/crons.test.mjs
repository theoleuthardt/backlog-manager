import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { chmodSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, it } from "node:test";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));

function entrypoints(file) {
  const text = readFileSync(join(root, file), "utf8");
  const found = {};
  for (const service of ["price-check-cron", "steam-wishlist-sync-cron"]) {
    const start = text.indexOf(`\n  ${service}:`);
    const block = text.slice(start + 1, text.indexOf("\n\n", start + 1));
    const script = block.split("\n- |\n")[0] === block ? null : null;
    const lines = block.split("\n");
    const at = lines.findIndex((line) => line.trim() === "- |");
    const body = [];
    for (const line of lines.slice(at + 1)) {
      if (!line.startsWith("        ")) break;
      body.push(line.slice(8));
    }
    found[service] = body.join("\n").replaceAll("$$", "$");
    void script;
  }
  return found;
}

function runUntilTerminated(script) {
  const bin = mkdtempSync(join(tmpdir(), "blm-cron-"));
  writeFileSync(join(bin, "curl"), "#!/bin/sh\nsleep 60\n");
  chmodSync(join(bin, "curl"), 0o755);
  return new Promise((resolve) => {
    const child = spawn("sh", ["-c", script], {
      env: { PATH: `${bin}:${process.env.PATH}`, PRICE_CHECK_CRON_SECRET: "x" },
      stdio: "ignore",
    });
    const started = Date.now();
    setTimeout(() => child.kill("SIGTERM"), 400);
    const guard = setTimeout(() => {
      child.kill("SIGKILL");
      resolve({ code: null, ms: Date.now() - started, killed: true });
    }, 5000);
    child.on("exit", (code) => {
      clearTimeout(guard);
      resolve({ code, ms: Date.now() - started, killed: false });
    });
  });
}

for (const file of ["compose.prod.yml", "compose.yml"]) {
  describe(`the cron containers of ${file}`, () => {
    const scripts = entrypoints(file);
    for (const [service, script] of Object.entries(scripts)) {
      it(`${service} stops at once on SIGTERM, also while curl runs`, async () => {
        assert.match(script, /curl/);
        const result = await runUntilTerminated(script);
        assert.equal(result.killed, false, "had to be killed: SIGTERM is ignored");
        assert.equal(result.code, 0);
        assert.ok(result.ms < 3000, `took ${result.ms} ms`);
      });

      it(`${service} still sleeps between two runs`, () => {
        assert.match(script, /sleep \d+ &/);
        assert.match(script, /wait \$!/);
      });
    }
  });
}
