import { apiClient, apiErrorMessage } from "./client";
import { toEntryData, type BacklogEntryData } from "./backlog";
import { streamSse } from "./sseStream";
import type { components } from "./schema";

export interface SteamSyncProgress {
  processed: number;
  total: number;
}

type BacklogEntryResponse = components["schemas"]["BacklogEntryResponse"];

async function streamEntries<TResponse extends BacklogEntryResponse[]>(
  response: Response,
  onProgress: (progress: SteamSyncProgress) => void,
): Promise<BacklogEntryData[]> {
  const entries = await streamSse<SteamSyncProgress, TResponse>(response, {
    onProgress,
  });
  return entries.map(toEntryData);
}

export async function syncSteamPlaytimesStream(
  onProgress: (progress: SteamSyncProgress) => void,
): Promise<BacklogEntryData[]> {
  const { response, error } = await apiClient.POST(
    "/api/user/steam/sync/stream",
    { parseAs: "stream" },
  );
  if (error)
    throw new Error(
      apiErrorMessage(error, "Failed to sync Steam playtimes"),
    );
  return streamEntries(response, onProgress);
}

export async function importSteamLibraryStream(
  onProgress: (progress: SteamSyncProgress) => void,
): Promise<BacklogEntryData[]> {
  const { response, error } = await apiClient.POST(
    "/api/user/steam/import/stream",
    // null body = import everything not yet linked (the pre-preview
    // behavior); the app-id list variant below is what the Steam page
    // uses after a confirmed preview.
    { parseAs: "stream", body: null },
  );
  if (error)
    throw new Error(
      apiErrorMessage(error, "Failed to import Steam library"),
    );
  return streamEntries(response, onProgress);
}

export async function importSteamLibraryAppIdsStream(
  appIds: number[],
  onProgress: (progress: SteamSyncProgress) => void,
): Promise<BacklogEntryData[]> {
  const { response, error } = await apiClient.POST(
    "/api/user/steam/import/stream",
    { parseAs: "stream", body: appIds.map((appid) => ({ appid })) },
  );
  if (error)
    throw new Error(
      apiErrorMessage(error, "Failed to import Steam library"),
    );
  return streamEntries(response, onProgress);
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
  const { response, error } = await apiClient.POST(
    "/api/user/steam/library/preview/stream",
    { parseAs: "stream" },
  );
  if (error)
    throw new Error(
      apiErrorMessage(error, "Failed to load Steam library preview"),
    );
  const items = await streamSse<SteamSyncProgress, SteamPreviewItemResponse[]>(
    response,
    { onProgress },
  );
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
  const { response, error } = await apiClient.POST(
    "/api/user/steam/wishlist/import/stream",
    { parseAs: "stream", body: items },
  );
  if (error)
    throw new Error(
      apiErrorMessage(error, "Failed to import Steam wishlist"),
    );
  return streamEntries(response, onProgress);
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