import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, it } from "node:test";

import { buildManifest, safeAssetName, writeManifest } from "./updater-manifest.mjs";

const REPO = "theoleuthardt/backlog-manager";

function seed(dir, files) {
  for (const [relative, content] of Object.entries(files)) {
    const target = path.join(dir, relative);
    mkdirSync(path.dirname(target), { recursive: true });
    writeFileSync(target, content);
  }
}

const RELEASE_FILES = {
  "macos/Backlog Manager.app.tar.gz": "mac-bundle",
  "macos/Backlog Manager.app.tar.gz.sig": "mac-sig\n",
  "dmg/Backlog Manager_1.2.3_aarch64.dmg": "dmg",
  "appimage/Backlog Manager_1.2.3_amd64.AppImage": "appimage",
  "appimage/Backlog Manager_1.2.3_amd64.AppImage.sig": "linux-sig\n",
  "deb/Backlog Manager_1.2.3_amd64.deb": "deb",
  "nsis/Backlog Manager_1.2.3_x64-setup.exe": "nsis",
  "nsis/Backlog Manager_1.2.3_x64-setup.exe.sig": "win-sig\n",
  "msi/Backlog Manager_1.2.3_x64_en-US.msi": "msi",
};

describe("safeAssetName", () => {
  it("replaces whitespace so the release asset url is predictable", () => {
    assert.equal(
      safeAssetName("Backlog Manager_1.2.3_amd64.AppImage"),
      "Backlog-Manager_1.2.3_amd64.AppImage",
    );
  });
});

describe("buildManifest", () => {
  it("maps every updatable platform to its download url and signature", () => {
    const manifest = buildManifest({
      version: "1.2.3",
      tag: "v1.2.3",
      repo: REPO,
      pubDate: "2026-09-28T10:00:00.000Z",
      assets: [
        { platform: "darwin-aarch64", name: "Backlog-Manager.app.tar.gz", signature: "mac-sig" },
        { platform: "linux-x86_64-appimage", name: "Backlog-Manager_1.2.3_amd64.AppImage", signature: "linux-sig" },
        { platform: "windows-x86_64-nsis", name: "Backlog-Manager_1.2.3_x64-setup.exe", signature: "win-sig" },
      ],
    });

    assert.deepEqual(manifest, {
      version: "1.2.3",
      pub_date: "2026-09-28T10:00:00.000Z",
      platforms: {
        "darwin-aarch64": {
          signature: "mac-sig",
          url: `https://github.com/${REPO}/releases/download/v1.2.3/Backlog-Manager.app.tar.gz`,
        },
        "linux-x86_64-appimage": {
          signature: "linux-sig",
          url: `https://github.com/${REPO}/releases/download/v1.2.3/Backlog-Manager_1.2.3_amd64.AppImage`,
        },
        "windows-x86_64-nsis": {
          signature: "win-sig",
          url: `https://github.com/${REPO}/releases/download/v1.2.3/Backlog-Manager_1.2.3_x64-setup.exe`,
        },
      },
    });
  });
});

describe("writeManifest", () => {
  it("renames signed payloads, finds their signatures and writes latest.json", () => {
    const dir = mkdtempSync(path.join(tmpdir(), "updater-manifest-"));
    seed(dir, RELEASE_FILES);

    const manifest = writeManifest({ dir, version: "1.2.3", tag: "v1.2.3", repo: REPO });

    assert.deepEqual(Object.keys(manifest.platforms).sort(), [
      "darwin-aarch64",
      "linux-x86_64-appimage",
      "windows-x86_64-nsis",
    ]);
    assert.equal(manifest.platforms["darwin-aarch64"].signature, "mac-sig");
    assert.equal(manifest.platforms["linux-x86_64-appimage"].signature, "linux-sig");
    assert.equal(manifest.platforms["windows-x86_64-nsis"].signature, "win-sig");
    assert.equal(
      manifest.platforms["darwin-aarch64"].url,
      `https://github.com/${REPO}/releases/download/v1.2.3/Backlog-Manager_1.2.3_aarch64.app.tar.gz`,
    );

    assert.ok(existsSync(path.join(dir, "macos/Backlog-Manager_1.2.3_aarch64.app.tar.gz")));
    assert.ok(existsSync(path.join(dir, "appimage/Backlog-Manager_1.2.3_amd64.AppImage")));
    assert.ok(existsSync(path.join(dir, "nsis/Backlog-Manager_1.2.3_x64-setup.exe")));
    assert.ok(!existsSync(path.join(dir, "appimage/Backlog Manager_1.2.3_amd64.AppImage")));

    const written = JSON.parse(readFileSync(path.join(dir, "latest.json"), "utf8"));
    assert.equal(written.version, "1.2.3");
    assert.deepEqual(Object.keys(written.platforms), Object.keys(manifest.platforms));
  });

  it("fails when a platform's signed updater payload is missing", () => {
    const dir = mkdtempSync(path.join(tmpdir(), "updater-manifest-"));
    const { "nsis/Backlog Manager_1.2.3_x64-setup.exe.sig": _sig, ...withoutWindowsSig } = RELEASE_FILES;
    seed(dir, withoutWindowsSig);

    assert.throws(
      () => writeManifest({ dir, version: "1.2.3", tag: "v1.2.3", repo: REPO }),
      /windows-x86_64/,
    );
  });
});
