import { useEffect } from "react";
import { toast } from "sonner";
import { useIsTauri } from "~/hooks/useIsTauri";
import { checkForUpdate, installUpdate, type AppUpdate } from "~/lib/appUpdate";

const UPDATE_TOAST_ID = "app-update";

async function installWithToast(update: AppUpdate) {
  toast.loading("Downloading update...", { id: UPDATE_TOAST_ID });
  try {
    await installUpdate(update, (percent) => {
      toast.loading(
        percent === null
          ? "Downloading update..."
          : `Downloading update... ${percent}%`,
        { id: UPDATE_TOAST_ID },
      );
    });
  } catch {
    toast.error("The update could not be installed.", { id: UPDATE_TOAST_ID });
  }
}

/**
 * Checks for a newer release once when the desktop app starts and offers
 * to install it. Renders nothing, and does nothing in the browser build or
 * when the check itself fails (offline, no release published yet) - the
 * manual check on the account page reports errors instead.
 */
export function AppUpdater() {
  const isTauri = useIsTauri();

  useEffect(() => {
    if (!isTauri) return;

    void checkForUpdate()
      .then((update) => {
        if (!update) return;
        toast(`Backlog Manager ${update.version} is available`, {
          id: UPDATE_TOAST_ID,
          duration: Infinity,
          action: {
            label: "Install & restart",
            onClick: () => void installWithToast(update),
          },
        });
      })
      .catch(() => undefined);
  }, [isTauri]);

  return null;
}
