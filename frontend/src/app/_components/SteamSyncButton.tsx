"use client";
import { RefreshCw } from "lucide-react";
import { toast } from "sonner";
import { Button } from "shadcn_components/ui/button";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "shadcn_components/ui/tooltip";
import { useSyncSteamPlaytimesStream } from "~/hooks/useBacklog";

const RING_RADIUS = 16;
const RING_CIRCUMFERENCE = 2 * Math.PI * RING_RADIUS;

/**
 * Icon-only button that syncs playtimes from Steam. While running the
 * icon spins and, once the total is known, a ring around the button
 * fills with the progress; the tooltip spells out the exact count.
 */
export const SteamSyncButton = ({ className = "" }: { className?: string }) => {
  const { run, isRunning, progress } = useSyncSteamPlaytimesStream();

  const handleSync = async () => {
    try {
      const updated = await run();
      toast.success(
        updated.length > 0
          ? `Synced ${updated.length} game${updated.length === 1 ? "" : "s"} from Steam`
          : "Steam is already up to date",
      );
    } catch (error) {
      toast.error(
        error instanceof Error
          ? error.message
          : "Failed to sync Steam playtimes",
      );
    }
  };

  const label =
    isRunning && progress
      ? `Syncing playtimes ${progress.processed}/${progress.total}`
      : isRunning
        ? "Syncing playtimes..."
        : "Sync Steam playtimes";
  const fraction =
    progress && progress.total > 0 ? progress.processed / progress.total : 0;

  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Button
          type="button"
          variant="outline"
          size="icon"
          onClick={handleSync}
          disabled={isRunning}
          aria-label={label}
          className={`relative h-9 w-9 rounded-full disabled:opacity-100 ${className}`}
        >
          {isRunning && progress && (
            <svg
              aria-hidden="true"
              viewBox="0 0 36 36"
              className="pointer-events-none absolute inset-0 h-full w-full -rotate-90"
            >
              <circle
                cx="18"
                cy="18"
                r={RING_RADIUS}
                fill="none"
                stroke="var(--t-accent)"
                strokeWidth="2.5"
                strokeLinecap="round"
                strokeDasharray={RING_CIRCUMFERENCE}
                strokeDashoffset={RING_CIRCUMFERENCE * (1 - fraction)}
                className="transition-[stroke-dashoffset] duration-300"
              />
            </svg>
          )}
          <RefreshCw className={`h-4 w-4 ${isRunning ? "animate-spin" : ""}`} />
        </Button>
      </TooltipTrigger>
      <TooltipContent>{label}</TooltipContent>
    </Tooltip>
  );
};
