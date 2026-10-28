import assert from "node:assert/strict";
import { generateKeyPairSync } from "node:crypto";
import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, it } from "node:test";

import {
  buildAppUpdateManifest,
  publicKeyBase64FromSeed,
  sha256Hex,
  signMessage,
  updateMessage,
  verifyMessage,
} from "./app-update-manifest.mjs";

const REPO = "theoleuthardt/backlog-manager";

function newSeed() {
  const { privateKey } = generateKeyPairSync("ed25519");
  return privateKey.export({ format: "der", type: "pkcs8" }).subarray(-32).toString("base64");
}

function seedDir(files) {
  const dir = mkdtempSync(path.join(tmpdir(), "app-update-"));
  for (const [relative, content] of Object.entries(files)) {
    const target = path.join(dir, relative);
    mkdirSync(path.dirname(target), { recursive: true });
    writeFileSync(target, content);
  }
  return dir;
}

const RELEASE_FILES = {
  "linux/Backlog-Manager_1.2.3_linux_x64.AppImage": "appimage",
  "linux/Backlog-Manager_1.2.3_linux_x64.deb": "deb",
  "linux/Backlog-Manager_1.2.3_linux_x64.rpm": "rpm",
  "macos/Backlog-Manager_1.2.3_macos_universal.dmg": "dmg",
  "windows/Backlog-Manager_1.2.3_windows_x64.exe": "exe",
  "android/Backlog-Manager_1.2.3_android_arm64.apk": "apk",
  "ios/Backlog-Manager_1.2.3_ios.ipa": "ipa",
};

describe("signatures", () => {
  it("verify with the public key of the seed", () => {
    const seed = newSeed();
    const message = updateMessage({ version: "1.2.3", key: "linux-x64-appimage", sha256: "ab" });
    const signature = signMessage(seed, message);

    assert.equal(verifyMessage(publicKeyBase64FromSeed(seed), message, signature), true);
  });

  it("do not verify for another message or another key", () => {
    const seed = newSeed();
    const message = updateMessage({ version: "1.2.3", key: "linux-x64-appimage", sha256: "ab" });
    const signature = signMessage(seed, message);
    const other = updateMessage({ version: "1.2.4", key: "linux-x64-appimage", sha256: "ab" });

    assert.equal(verifyMessage(publicKeyBase64FromSeed(seed), other, signature), false);
    assert.equal(verifyMessage(publicKeyBase64FromSeed(newSeed()), message, signature), false);
  });

  it("refuse a private key that is not a 32 byte seed", () => {
    assert.throws(() => signMessage("AAAA", "x"), /32 byte seed/);
  });
});

describe("buildAppUpdateManifest", () => {
  const seed = newSeed();
  const build = (dir) =>
    buildAppUpdateManifest({
      dir,
      version: "1.2.3",
      tag: "v1.2.3",
      repo: REPO,
      privateKey: seed,
      notes: "Fixes",
      pubDate: "2026-10-12T00:00:00.000Z",
    });

  it("lists APK, AppImage, DMG and EXE but not DEB, RPM and IPA", () => {
    const manifest = build(seedDir(RELEASE_FILES));

    assert.deepEqual(Object.keys(manifest.payloads).sort(), [
      "android-arm64-apk",
      "linux-x64-appimage",
      "macos-universal-dmg",
      "windows-x64-exe",
    ]);
    assert.equal(manifest.version, "1.2.3");
    assert.equal(manifest.page_url, `https://github.com/${REPO}/releases/tag/v1.2.3`);
  });

  it("points at the release asset and carries its hash and size", () => {
    const payload = build(seedDir(RELEASE_FILES)).payloads["linux-x64-appimage"];

    assert.equal(
      payload.url,
      `https://github.com/${REPO}/releases/download/v1.2.3/Backlog-Manager_1.2.3_linux_x64.AppImage`,
    );
    assert.equal(payload.sha256, sha256Hex(Buffer.from("appimage")));
    assert.equal(payload.size, "appimage".length);
  });

  it("signs every payload for its own version, key and hash", () => {
    const manifest = build(seedDir(RELEASE_FILES));
    const publicKey = publicKeyBase64FromSeed(seed);

    for (const [key, payload] of Object.entries(manifest.payloads)) {
      const message = updateMessage({ version: "1.2.3", key, sha256: payload.sha256 });
      assert.equal(verifyMessage(publicKey, message, payload.signature), true, key);
    }
    const linux = manifest.payloads["linux-x64-appimage"];
    const swapped = updateMessage({ version: "1.2.3", key: "windows-x64-exe", sha256: linux.sha256 });
    assert.equal(verifyMessage(publicKey, swapped, linux.signature), false);
  });

  it("offers the Android APK, but nothing for iOS, which cannot update itself", () => {
    const manifest = build(seedDir(RELEASE_FILES));

    assert.equal(
      manifest.payloads["android-arm64-apk"].url,
      `https://github.com/${REPO}/releases/download/v1.2.3/Backlog-Manager_1.2.3_android_arm64.apk`,
    );
    assert.equal(
      Object.keys(manifest.payloads).some((key) => key.startsWith("ios")),
      false,
    );
  });

  it("throws when the Android APK is missing", () => {
    const files = { ...RELEASE_FILES };
    delete files["android/Backlog-Manager_1.2.3_android_arm64.apk"];

    assert.throws(() => build(seedDir(files)), /android-arm64-apk/);
  });

  it("throws when a platform has no installer", () => {
    const files = { ...RELEASE_FILES };
    delete files["macos/Backlog-Manager_1.2.3_macos_universal.dmg"];

    assert.throws(() => build(seedDir(files)), /macos-universal-dmg/);
  });
});
