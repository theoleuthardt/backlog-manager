/**
 * Decides the version of the next desktop release.
 *
 * Usage (release pipeline):
 *   node scripts/release-version.mjs <latest tag or ""> <package.json version> <requested version or "">
 * and prints `version=X.Y.Z` and `tag=vX.Y.Z` for `$GITHUB_OUTPUT`.
 *
 * Without a requested version the patch of the latest `v*.*.*` tag is bumped
 * (or the package.json version is used while no tag exists). A requested
 * version must be plain `X.Y.Z` and greater than the latest tag: the Tauri
 * updater only offers versions newer than the installed one, and a tag that
 * already exists cannot be released again. Later automatic bumps continue
 * from whatever was released last.
 */
import { pathToFileURL } from "node:url";

const VERSION_PATTERN = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;

export function parseVersion(text) {
  const match = VERSION_PATTERN.exec(text);
  return match ? [Number(match[1]), Number(match[2]), Number(match[3])] : null;
}

export function compareVersions(a, b) {
  const left = parseVersion(a);
  const right = parseVersion(b);
  for (let index = 0; index < 3; index += 1) {
    if (left[index] !== right[index]) return left[index] - right[index];
  }
  return 0;
}

export function nextReleaseVersion({ latestTag, packageVersion, requested }) {
  const latest = latestTag ? latestTag.replace(/^v/, "") : "";
  if (latest && !parseVersion(latest)) {
    throw new Error(`The latest tag "${latestTag}" is not a plain vX.Y.Z version`);
  }

  const wanted = requested.trim().replace(/^v/, "");
  let version;
  if (wanted) {
    if (!parseVersion(wanted)) {
      throw new Error(`Requested version "${requested.trim()}" must be plain X.Y.Z (for example 0.9.0)`);
    }
    if (latest && compareVersions(wanted, latest) <= 0) {
      throw new Error(`Requested version ${wanted} must be greater than the latest release ${latest}`);
    }
    version = wanted;
  } else if (latest) {
    const [major, minor, patch] = parseVersion(latest);
    version = `${major}.${minor}.${patch + 1}`;
  } else {
    version = packageVersion;
  }

  return { version, tag: `v${version}` };
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [latestTag = "", packageVersion = "", requested = ""] = process.argv.slice(2);
  try {
    const { version, tag } = nextReleaseVersion({ latestTag, packageVersion, requested });
    console.log(`version=${version}`);
    console.log(`tag=${tag}`);
  } catch (error) {
    console.error(`::error::${error.message}`);
    process.exit(1);
  }
}
