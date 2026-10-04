import { apiClient, apiErrorMessage } from "./client";
import { toEntryData, type BacklogEntryData } from "./backlog";
import { streamSse } from "./sseStream";
import type { components } from "./schema";

export interface IgdbSyncProgress {
  processed: number;
  total: number;
}

type BacklogEntryResponse = components["schemas"]["BacklogEntryResponse"];

export async function getIgdbSyncPendingCount(): Promise<number> {
  const { data, error } = await apiClient.GET("/api/igdb-sync/pending-count");
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to count entries to sync"));
  return data;
}

export async function syncIgdbDataStream(
  onProgress: (progress: IgdbSyncProgress) => void,
): Promise<BacklogEntryData[]> {
  const { response, error } = await apiClient.POST("/api/igdb-sync/stream", {
    parseAs: "stream",
  });
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to sync IGDB game data"));
  const entries = await streamSse<IgdbSyncProgress, BacklogEntryResponse[]>(
    response,
    { onProgress },
  );
  return entries.map(toEntryData);
}
