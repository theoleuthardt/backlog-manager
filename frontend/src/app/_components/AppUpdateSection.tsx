"use client";

import { useIsTauri } from "~/hooks/useIsTauri";
import { useAppUpdater } from "~/hooks/useAppUpdater";
import { Button } from "~/components/ui/button";
import { OUTLINE_BUTTON, FILLED_BUTTON } from "~/lib/buttonStyles";

/**
 * Manual "check for updates" card for the desktop app. Renders nothing in
 * the browser build, where the app is always the freshly deployed version.
 */
export function AppUpdateSection() {
  const isTauri = useIsTauri();
  const { status, update, progress, check, install } = useAppUpdater();

  if (!isTauri) return null;

  const isBusy = status === "checking" || status === "installing";

  return (
    <div className="rounded-lg border-2 border-white bg-black p-6">
      <h2 className="mb-2 text-xl font-semibold">App Updates</h2>
      <p className="mb-4 text-sm text-gray-300">
        Backlog Manager checks for a new version when it starts. You can also
        check manually and install it right here.
      </p>
      <div className="flex flex-wrap items-center gap-3">
        {status === "available" || status === "installing" ? (
          <Button
            className={FILLED_BUTTON}
            onClick={() => void install()}
            disabled={isBusy}
          >
            {status === "installing"
              ? `Installing${progress === null ? "" : ` ${progress}%`}...`
              : `Install ${update?.version ?? "update"} & restart`}
          </Button>
        ) : (
          <Button
            variant="outline"
            className={OUTLINE_BUTTON}
            onClick={() => void check()}
            disabled={isBusy}
          >
            {status === "checking" ? "Checking..." : "Check for updates"}
          </Button>
        )}
        {status === "up-to-date" && (
          <span className="text-sm text-gray-300">
            You are on the latest version.
          </span>
        )}
        {status === "error" && (
          <span className="text-sm text-red-400">
            The update check failed. Try again later.
          </span>
        )}
      </div>
      {status === "available" && update?.body && (
        <p className="mt-4 text-sm whitespace-pre-line text-gray-300">
          {update.body}
        </p>
      )}
    </div>
  );
}
