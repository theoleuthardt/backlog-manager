import { useCallback, useState } from "react";
import {
  checkForUpdate,
  installUpdate,
  type AppUpdate,
} from "~/lib/appUpdate";

export type AppUpdaterStatus =
  | "idle"
  | "checking"
  | "up-to-date"
  | "available"
  | "installing"
  | "error";

/**
 * Drives a manual "check for updates" flow against the Tauri updater:
 * `check` looks for a newer signed release, `install` downloads it (with
 * `progress` as a percentage, null while the size is unknown) and restarts
 * the app.
 */
export function useAppUpdater() {
  const [status, setStatus] = useState<AppUpdaterStatus>("idle");
  const [update, setUpdate] = useState<AppUpdate | null>(null);
  const [progress, setProgress] = useState<number | null>(null);

  const check = useCallback(async () => {
    setStatus("checking");
    try {
      const found = await checkForUpdate();
      setUpdate(found);
      setStatus(found ? "available" : "up-to-date");
    } catch {
      setStatus("error");
    }
  }, []);

  const install = useCallback(async () => {
    if (!update) return;
    setProgress(0);
    setStatus("installing");
    try {
      await installUpdate(update, setProgress);
    } catch {
      setStatus("error");
    }
  }, [update]);

  return { status, update, progress, check, install };
}
