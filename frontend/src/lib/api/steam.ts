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
