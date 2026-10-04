"use client";
import { useState } from "react";
import { DatabaseZap, Loader2 } from "lucide-react";
import { toast } from "sonner";
import { Button } from "shadcn_components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "shadcn_components/ui/dialog";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "shadcn_components/ui/tooltip";
import {
  useIgdbSyncPendingCount,
  useSyncIgdbDataStream,
} from "~/hooks/useBacklog";

/**
 * Icon-only button that adds IGDB game data (genre, description, trailer,
 * beat times) retroactively to every entry that lacks it. A confirmation
 * dialog names how many entries are affected; once started it shows a
 * progress bar and can't be closed until the sync finished.
 */
export const IgdbSyncButton = ({ className = "" }: { className?: string }) => {
  const [open, setOpen] = useState(false);
  const { run, isRunning, progress } = useSyncIgdbDataStream();
  const pending = useIgdbSyncPendingCount(open && !isRunning);

  const handleStart = async () => {
    try {
      const updated = await run();
      toast.success(
        updated.length > 0
          ? `Updated ${updated.length} game${updated.length === 1 ? "" : "s"} with IGDB data`
          : "No IGDB data could be added",
      );
      setOpen(false);
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Failed to sync IGDB data",
      );
    }
  };

  const fraction =
    progress && progress.total > 0 ? progress.processed / progress.total : 0;
  const count = pending.data;

  return (
    <>
      <Tooltip>
        <TooltipTrigger asChild>
          <Button
            type="button"
            variant="outline"
            size="icon"
            onClick={() => setOpen(true)}
            aria-label="Sync IGDB game data"
            className={`h-9 w-9 rounded-full ${className}`}
          >
            <DatabaseZap className="h-4 w-4" />
          </Button>
        </TooltipTrigger>
        <TooltipContent>Sync IGDB game data</TooltipContent>
      </Tooltip>

      <Dialog
        open={open}
        onOpenChange={(next) => {
          if (!isRunning) setOpen(next);
        }}
      >
        <DialogContent
          className="bg-background border-2 border-white"
          showCloseButton={!isRunning}
        >
          <DialogHeader>
            <DialogTitle>Sync IGDB game data</DialogTitle>
            <DialogDescription>
              Looks up every game that is missing a genre or description on IGDB
              and fills in what is missing: genre, description, trailer and beat
              times. Values you entered yourself are never overwritten.
            </DialogDescription>
          </DialogHeader>

          {isRunning ? (
            <div className="space-y-2" role="status" aria-live="polite">
              <div className="h-2 overflow-hidden rounded-full bg-white/15">
                <div
                  className="bg-primary h-full rounded-full transition-[width] duration-300"
                  style={{ width: `${fraction * 100}%` }}
                />
              </div>
              <p className="text-sm text-white/70">
                {progress
                  ? `Looking up games ${progress.processed}/${progress.total}`
                  : "Starting..."}
              </p>
            </div>
          ) : (
            <p className="text-sm text-white/70" role="status">
              {pending.isPending
                ? "Counting games..."
                : pending.isError
                  ? "Could not count the games to sync."
                  : count === 0
                    ? "Every game already has IGDB data."
                    : `${count} game${count === 1 ? "" : "s"} will be looked up.`}
            </p>
          )}

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              disabled={isRunning}
              onClick={() => setOpen(false)}
            >
              Cancel
            </Button>
            <Button
              type="button"
              disabled={isRunning || !count}
              onClick={() => void handleStart()}
            >
              {isRunning ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  Syncing...
                </>
              ) : (
                "Start sync"
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
};
