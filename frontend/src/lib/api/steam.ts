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

type SteamPreviewItemResponse = components["schemas"]["SteamPreviewItem"];

export interface SteamPreviewItem {
  steamAppId: number;
  title: string;
  imageLink: string | null;
}

export async function previewSteamLibraryStream(
  onProgress: (progress: SteamSyncProgress) => void,
): Promise<SteamPreviewItem[]> {
  const items = await streamSse<
    SteamSyncProgress,
    SteamPreviewItemResponse[]
  >("/api/user/steam/library/preview/stream", { onProgress });
  return items.map((item) => ({
    steamAppId: item.steam_app_id,
    title: item.title,
    imageLink: item.image_link ?? null,
  }));
}

export async function getSteamWishlistPreview(): Promise<
  SteamPreviewItem[]
> {
  const { data, error } = await apiClient.GET(
    "/api/user/steam/wishlist/preview",
  );
  if (error)
    throw new Error(
      apiErrorMessage(error, "Failed to load Steam wishlist preview"),
    );
  return data.map((item) => ({
    steamAppId: item.steam_app_id,
    title: item.title,
    imageLink: item.image_link ?? null,
  }));
}

export interface SteamWishlistImportItem {
  appid: number;
}

export async function importSteamWishlistStream(
  items: SteamWishlistImportItem[],
  onProgress: (progress: SteamSyncProgress) => void,
): Promise<BacklogEntryData[]> {
  const entries = await streamSse<SteamSyncProgress, BacklogEntryResponse[]>(
    "/api/user/steam/wishlist/import/stream",
    { onProgress, body: items },
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
