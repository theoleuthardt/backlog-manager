import { apiClient, apiErrorMessage } from "./client";
import { toEntryData, type BacklogEntryData } from "./backlog";
import { streamSse } from "./sseStream";
import type { components } from "./schema";

export interface SteamSyncProgress {
  processed: number;
  total: number;
}

type BacklogEntryResponse = components["schemas"]["BacklogEntryResponse"];

export async function syncSteamPlaytimesStream(
  onProgress: (progress: SteamSyncProgress) => void,
): Promise<BacklogEntryData[]> {
  const entries = await streamSse<SteamSyncProgress, BacklogEntryResponse[]>(
    "/api/user/steam/sync/stream",
    { onProgress },
  );
  return entries.map(toEntryData);
}

export async function importSteamLibraryStream(
  onProgress: (progress: SteamSyncProgress) => void,
): Promise<BacklogEntryData[]> {
  const entries = await streamSse<SteamSyncProgress, BacklogEntryResponse[]>(
    "/api/user/steam/import/stream",
    { onProgress },
  );
  return entries.map(toEntryData);
}

export interface AchievementInfo {
  apiname: string;
  displayName: string;
  description: string | null;
  icon: string | null;
  achieved: boolean;
  unlockTime: number;
  hidden: boolean;
}

export interface AchievementProgress {
  unlocked: number;
  total: number;
  achievements: AchievementInfo[];
}

export async function getSteamAchievements(
  steamAppId: number,
): Promise<AchievementProgress> {
  const { data, error } = await apiClient.GET("/api/user/steam/achievements", {
    params: { query: { steam_app_id: steamAppId } },
  });
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to load achievements"));
  return {
    unlocked: data.unlocked,
    total: data.total,
    achievements: data.achievements.map((achievement) => ({
      apiname: achievement.apiname,
      displayName: achievement.display_name,
      description: achievement.description,
      icon: achievement.icon,
      achieved: achievement.achieved,
      unlockTime: achievement.unlock_time,
      hidden: achievement.hidden,
    })),
  };
}
