/**
 * Builds `app-update.json`, the manifest the Flutter app reads to update
 * itself in place, from the installers of one release.
 *
 * Usage (release pipeline):
 *   APP_UPDATE_PRIVATE_KEY=<base64 seed> \
 *   node scripts/app-update-manifest.mjs <dir> <version> <tag> <owner/repo>
 *
 * Every payload carries its SHA-256 and an Ed25519 signature of
 * `blm-update-v1:<version>:<key>:<sha256>`, so a signature is valid for one
 * file of one version for one platform only. The keys are
 * `{os}-{arch}-{format}`: an install that cannot apply a format (DEB, RPM)
 * finds no entry and stays notify-only. Without a private key nothing is
 * written and the release ships without in-place updates.
 */
import { createHash, createPrivateKey, createPublicKey, sign, verify } from "node:crypto";
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const PKCS8_ED25519_PREFIX = Buffer.from("302e020100300506032b657004220420", "hex");
const SPKI_ED25519_PREFIX = Buffer.from("302a300506032b6570032100", "hex");

const PAYLOADS = [
  { key: "linux-x64-appimage", pattern: /_linux_x64\.AppImage$/i },
  { key: "macos-universal-dmg", pattern: /_macos_universal\.dmg$/i },
  { key: "windows-x64-exe", pattern: /_windows_x64\.exe$/i },
];

export function sha256Hex(buffer) {
  return createHash("sha256").update(buffer).digest("hex");
}

export function updateMessage({ version, key, sha256 }) {
  return `blm-update-v1:${version}:${key}:${sha256}`;
}

function privateKeyFromSeed(seedBase64) {
  const seed = Buffer.from(seedBase64.trim(), "base64");
  if (seed.length !== 32) {
    throw new Error("The update private key must be a base64 encoded 32 byte seed");
  }
  return createPrivateKey({
    key: Buffer.concat([PKCS8_ED25519_PREFIX, seed]),
    format: "der",
    type: "pkcs8",
  });
}

export function publicKeyBase64FromSeed(seedBase64) {
  const spki = createPublicKey(privateKeyFromSeed(seedBase64)).export({
    format: "der",
    type: "spki",
  });
  return Buffer.from(spki).subarray(SPKI_ED25519_PREFIX.length).toString("base64");
}

export function signMessage(seedBase64, message) {
  return sign(null, Buffer.from(message), privateKeyFromSeed(seedBase64)).toString("base64");
}

export function verifyMessage(publicKeyBase64, message, signatureBase64) {
  const publicKey = createPublicKey({
    key: Buffer.concat([SPKI_ED25519_PREFIX, Buffer.from(publicKeyBase64, "base64")]),
    format: "der",
    type: "spki",
  });
  return verify(null, Buffer.from(message), publicKey, Buffer.from(signatureBase64, "base64"));
}

function listFiles(dir) {
  return readdirSync(dir, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => path.join(entry.parentPath ?? entry.path, entry.name));
}

/**
 * Signs the installers found in `dir` and returns the manifest. Throws when
 * a platform has no installer, so a release never ships a manifest that
 * silently drops a platform.
 */
export function buildAppUpdateManifest({
  dir,
  version,
  tag,
  repo,
  privateKey,
  notes = "",
  pubDate = new Date().toISOString(),
}) {
  const files = listFiles(dir);
  const payloads = {};
  for (const { key, pattern } of PAYLOADS) {
    const file = files.find((candidate) => pattern.test(candidate));
    if (!file) throw new Error(`No installer found for ${key} in ${dir}`);
    const content = readFileSync(file);
    const sha256 = sha256Hex(content);
    payloads[key] = {
      url: `https://github.com/${repo}/releases/download/${tag}/${path.basename(file)}`,
      sha256,
      size: content.length,
      signature: signMessage(privateKey, updateMessage({ version, key, sha256 })),
    };
  }
  return {
    version,
    pub_date: pubDate,
    notes,
    page_url: `https://github.com/${repo}/releases/tag/${tag}`,
    payloads,
  };
}

function main() {
  const [dir, version, tag, repo] = process.argv.slice(2);
  if (!dir || !version || !tag || !repo) {
    console.error("Usage: node scripts/app-update-manifest.mjs <dir> <version> <tag> <owner/repo>");
    process.exit(1);
  }
  const privateKey = process.env.APP_UPDATE_PRIVATE_KEY ?? "";
  if (privateKey.trim() === "") {
    console.log("APP_UPDATE_PRIVATE_KEY is not set: no app-update.json, no in-place updates.");
    return;
  }
  const manifest = buildAppUpdateManifest({ dir, version, tag, repo, privateKey });
  const target = path.join(dir, "app-update.json");
  writeFileSync(target, `${JSON.stringify(manifest, null, 2)}\n`);
  console.log(`Wrote ${target} for ${Object.keys(manifest.payloads).join(", ")}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) main();
