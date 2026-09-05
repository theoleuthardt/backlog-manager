import { apiClient, apiErrorMessage } from "./client";

export type CSVRecord = Record<string, string>;

export interface MissingGame {
  title: string;
  genre: string;
  platform: string;
  status: string;
}

export interface RecordError {
  title: string;
  error: string;
}

export interface ImportResult {
  success: number;
  failed: number;
  errors: RecordError[];
  missingGames: MissingGame[];
}

export interface ImportCsvParams {
  content: string;
  titleColumn: string;
  genreColumn: string;
  platformColumn: string;
  statusColumn: string;
  sessionId?: string;
}

export async function parseCsv(content: string): Promise<CSVRecord[]> {
  const { data, error } = await apiClient.POST("/api/csv/parse", {
    body: { content },
  });
  if (error) throw new Error(apiErrorMessage(error, "Failed to parse CSV"));
  return data as CSVRecord[];
}

export async function importCsv(
  params: ImportCsvParams,
): Promise<ImportResult> {
  const { data, error } = await apiClient.POST("/api/csv/import", {
    body: {
      content: params.content,
      title_column: params.titleColumn,
      genre_column: params.genreColumn,
      platform_column: params.platformColumn,
      status_column: params.statusColumn,
      session_id: params.sessionId,
    },
  });
  if (error) throw new Error(apiErrorMessage(error, "Failed to import CSV"));
  return {
    success: data.success ?? 0,
    failed: data.failed ?? 0,
    errors: data.errors ?? [],
    missingGames: data.missing_games ?? [],
  };
}

export async function getImportProgress(sessionId: string): Promise<number> {
  const { data, error } = await apiClient.GET(
    "/api/csv/import/{session_id}/progress",
    { params: { path: { session_id: sessionId } } },
  );
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to get import progress"));
  return data.processed;
}

export async function cancelImport(sessionId: string): Promise<void> {
  const { error } = await apiClient.POST(
    "/api/csv/import/{session_id}/cancel",
    {
      params: { path: { session_id: sessionId } },
    },
  );
  if (error) throw new Error(apiErrorMessage(error, "Failed to cancel import"));
}
