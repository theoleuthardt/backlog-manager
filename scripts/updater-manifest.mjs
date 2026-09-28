/**
 * Builds the `latest.json` manifest that tauri-plugin-updater polls, from the
 * signed updater payloads the desktop build leaves next to its installers.
 *
 * Usage (release pipeline): node scripts/updater-manifest.mjs <dir> <version> <tag> <owner/repo>
 *
 * Payloads are renamed to space-free asset names first, because GitHub
 * rewrites spaces in release asset names and the manifest URLs must match the
 * uploaded names exactly. Only macOS (app bundle tarball), Linux (AppImage)
 * and Windows (NSIS installer) support in-app updates; DEB, RPM, MSI and DMG
 * installers are not touched.
 */
import { existsSync, readdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const PLATFORMS = [
  {
    platform: "darwin-aarch64",
    pattern: /\.app\.tar\.gz$/,
    assetName: (_name, version) => `Backlog-Manager_${version}_aarch64.app.tar.gz`,
  },
  {
    platform: "linux-x86_64",
    pattern: /\.AppImage$/,
    assetName: (name) => safeAssetName(name),
  },
  {
    platform: "windows-x86_64",
    pattern: /-setup\.exe$/,
    assetName: (name) => safeAssetName(name),
  },
];

export function safeAssetName(name) {
  return name.replace(/\s+/g, "-");
}

function listFiles(dir) {
  return readdirSync(dir, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => path.join(entry.parentPath, entry.name));
}

export function buildManifest({ version, tag, repo, assets, pubDate = new Date().toISOString() }) {
  const platforms = {};
  for (const { platform, name, signature } of assets) {
    platforms[platform] = {
      signature,
      url: `https://github.com/${repo}/releases/download/${tag}/${name}`,
    };
  }
  return { version, pub_date: pubDate, platforms };
}

/**
 * Renames each platform's signed payload (and its `.sig`) to the space-free
 * asset name, then writes `latest.json` into `dir`. Throws when a platform's
 * payload or signature is missing, so a release never ships a manifest that
 * silently drops a platform.
 */
export function writeManifest({ dir, version, tag, repo }) {
  const files = listFiles(dir);
  const assets = PLATFORMS.map(({ platform, pattern, assetName }) => {
    const payload = files.find(
      (file) => pattern.test(file) && existsSync(`${file}.sig`),
    );
    if (!payload) {
      throw new Error(`No signed updater payload found for ${platform} in ${dir}`);
    }
    const name = assetName(path.basename(payload), version);
    const target = path.join(path.dirname(payload), name);
    const signature = readFileSync(`${payload}.sig`, "utf8").trim();
    renameSync(`${payload}.sig`, `${target}.sig`);
    renameSync(payload, target);
    return { platform, name, signature };
  });

  const manifest = buildManifest({ version, tag, repo, assets });
  writeFileSync(path.join(dir, "latest.json"), `${JSON.stringify(manifest, null, 2)}\n`);
  return manifest;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [dir, version, tag, repo] = process.argv.slice(2);
  if (!dir || !version || !tag || !repo) {
    console.error("Usage: updater-manifest.mjs <dir> <version> <tag> <owner/repo>");
    process.exit(1);
  }
  writeManifest({ dir, version, tag, repo });
}
