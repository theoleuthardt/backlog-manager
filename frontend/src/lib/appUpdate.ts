import type { Update } from "@tauri-apps/plugin-updater";

export type AppUpdate = Pick<Update, "version" | "body" | "downloadAndInstall">;

const CHECK_TIMEOUT_MS = 15_000;
const DOWNLOAD_TIMEOUT_MS = 10 * 60_000;

export function downloadPercent(downloaded: number, total: number | undefined) {
  if (!total) return null;
  return Math.min(100, Math.round((downloaded / total) * 100));
}

/**
 * Asks the Tauri updater whether a newer signed release exists at the
 * endpoint configured in tauri.conf.json. The plugins are imported lazily
 * so the static export never touches them outside the desktop app.
 */
export async function checkForUpdate(): Promise<AppUpdate | null> {
  const { check } = await import("@tauri-apps/plugin-updater");
  return check({ timeout: CHECK_TIMEOUT_MS });
}

/**
 * Downloads and installs the update, reporting progress as a percentage (or
 * null while the size is unknown), then restarts the app. On Windows the
 * installer exits the app itself before the restart is reached.
 */
export async function installUpdate(
  update: AppUpdate,
  onProgress: (percent: number | null) => void,
) {
  let total: number | undefined;
  let downloaded = 0;

  await update.downloadAndInstall(
    (event) => {
      if (event.event === "Started") {
        total = event.data.contentLength;
      } else if (event.event === "Progress") {
        downloaded += event.data.chunkLength;
        onProgress(downloadPercent(downloaded, total));
      }
    },
    { timeout: DOWNLOAD_TIMEOUT_MS },
  );

  const { relaunch } = await import("@tauri-apps/plugin-process");
  await relaunch();
}
