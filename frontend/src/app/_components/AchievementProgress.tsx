"use client";
import { useState } from "react";
import { ChevronDown, ChevronUp, Loader2, Trophy } from "lucide-react";
import { GameImage } from "components/GameImage";
import { useSteamAchievements } from "~/hooks/useBacklog";

interface AchievementProgressProps {
  steamAppId?: number;
}

export function AchievementProgress({ steamAppId }: AchievementProgressProps) {
  const [expanded, setExpanded] = useState(false);
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
      <button
        type="button"
        onClick={() => setExpanded(!expanded)}
        className="flex items-center gap-1 text-xs text-gray-400 hover:text-white"
      >
        {expanded ? "Hide" : "Show"} all achievements
        {expanded ? (
          <ChevronUp className="h-3 w-3" />
        ) : (
          <ChevronDown className="h-3 w-3" />
        )}
      </button>
      {expanded && (
        <div className="max-h-48 space-y-1 overflow-y-auto pr-1">
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
                width={24}
                height={24}
              />
              <div className="min-w-0 flex-1">
                <p className="truncate text-xs font-medium text-white">
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
      )}
    </div>
  );
}
