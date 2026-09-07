"use client";
import { useState } from "react";
import { Loader2, Trophy } from "lucide-react";
import { GameImage } from "components/GameImage";
import { useSteamAchievements } from "~/hooks/useBacklog";
import {
  Dialog,
  DialogContent,
  DialogTitle,
  DialogTrigger,
} from "shadcn_components/ui/dialog";

interface AchievementProgressProps {
  steamAppId?: number;
}

export function AchievementProgress({ steamAppId }: AchievementProgressProps) {
  const [open, setOpen] = useState(false);
  const { data, isLoading, isError } = useSteamAchievements(steamAppId);

  if (steamAppId === undefined) return null;
  if (isLoading) {
    return (
      <div className="flex items-center gap-2 text-sm text-gray-400">
        <Loader2 className="h-4 w-4 animate-spin" />
        Loading achievements...
      </div>
    );
  }
  if (isError || !data || data.total === 0) return null;

  const percentage = Math.round((data.unlocked / data.total) * 100);

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <span className="flex items-center gap-1.5 text-sm text-white">
          <Trophy className="h-4 w-4" />
          Achievements
        </span>
        <span className="text-sm text-gray-400">
          {data.unlocked}/{data.total} ({percentage}%)
        </span>
      </div>
      <div className="h-2 w-full overflow-hidden rounded-full bg-white/10">
        <div
          className="h-full bg-white transition-all"
          style={{ width: `${percentage}%` }}
        />
      </div>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogTrigger asChild>
          <button
            type="button"
            className="flex items-center gap-1 text-xs text-gray-400 hover:text-white"
          >
            Show all achievements
          </button>
        </DialogTrigger>
        <DialogContent className="flex h-[calc(100vh-6rem)] w-[calc(100vw-6rem)] max-w-2xl flex-col border-2 border-white bg-black p-6">
          <DialogTitle className="flex items-center gap-1.5 text-white">
            <Trophy className="h-4 w-4" />
            Achievements ({data.unlocked}/{data.total})
          </DialogTitle>
          <div className="flex-1 space-y-1 overflow-y-auto pr-1">
            {data.achievements.map((achievement) => (
              <div
                key={achievement.apiname}
                className={`flex items-center gap-2 rounded p-1 ${
                  achievement.achieved ? "" : "opacity-40"
                }`}
              >
                <GameImage
                  src={achievement.icon ?? ""}
                  alt={achievement.displayName}
                  width={32}
                  height={32}
                />
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium text-white">
                    {achievement.displayName}
                  </p>
                  {achievement.description && (
                    <p className="truncate text-xs text-gray-400">
                      {achievement.description}
                    </p>
                  )}
                </div>
              </div>
            ))}
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
