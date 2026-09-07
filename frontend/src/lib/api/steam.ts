import { apiClient, apiErrorMessage } from "./client";
import { toEntryData, type BacklogEntryData } from "./backlog";

export async function syncSteamPlaytimes(): Promise<BacklogEntryData[]> {
  const { data, error } = await apiClient.POST("/api/user/steam/sync");
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to sync Steam playtimes"));
  return data.map(toEntryData);
}

export async function importSteamLibrary(): Promise<BacklogEntryData[]> {
  const { data, error } = await apiClient.POST("/api/user/steam/import");
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to import Steam library"));
  return data.map(toEntryData);
}

export interface AchievementInfo {
  apiname: string;
  displayName: string;
  description: string | null;
  icon: string | null;
  achieved: boolean;
  unlockTime: number;
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
    })),
  };
}
