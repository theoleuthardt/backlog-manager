import { apiClient, apiErrorMessage } from "./client";
import { toEntryData, toNumber, type BacklogEntryData } from "./backlog";
import { streamSse } from "./sseStream";
import type { components } from "./schema";

export interface CsvImportProgress {
  processed: number;
  total: number;
}

export interface ColumnConfig {
  titleColumn: string;
  genreColumn: string;
  platformColumn: string;
  statusColumn: string;
  playtimeColumn: string | null;
  ratingColumn: string | null;
  completedAtColumn: string | null;
  noteColumns: string[];
  reviewColumns: string[];
}

type MatchCsvRequestBody = components["schemas"]["MatchCsvRequest"];

function toMatchCsvRequestBody(
  content: string,
  config: ColumnConfig,
): MatchCsvRequestBody {
  return {
    content,
    title_column: config.titleColumn,
    genre_column: config.genreColumn,
    platform_column: config.platformColumn,
    status_column: config.statusColumn,
    playtime_column: config.playtimeColumn,
    rating_column: config.ratingColumn,
    completed_at_column: config.completedAtColumn,
    note_columns: config.noteColumns,
    review_columns: config.reviewColumns,
  };
}

export async function getCsvHeaders(
  content: string,
): Promise<Record<string, string>> {
  const { data, error } = await apiClient.POST("/api/csv/headers", {
    body: { content },
  });
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to read CSV headers"));
  return data.headers;
}

export interface FieldDiff {
  field: string;
  existing: string;
  proposed: string;
}

export interface DuplicateMatch {
  backlogEntryId: number;
  title: string;
  diffs: FieldDiff[];
}

export interface CsvPreviewItem {
  rowIndex: number;
  title: string;
  genre: string;
  platform: string[];
  status: string;
  owned: boolean;
  playtime?: number;
  reviewStars?: number;
  note: string | null;
  review: string | null;
  completedAt: string | null;
  imageLink: string | null;
  description: string | null;
  mainTime?: number;
  mainPlusExtraTime?: number;
  completionTime?: number;
  matched: boolean;
  duplicates: DuplicateMatch[];
}

interface CsvPreviewItemResponse {
  row_index: number;
  title: string;
  genre: string;
  platform: string[];
  status: string;
  owned: boolean;
  playtime: string | null;
  review_stars: number | null;
  note: string | null;
  review: string | null;
  completed_at: string | null;
  image_link: string | null;
  description: string | null;
  main_time: string | null;
  main_plus_extra_time: string | null;
  completion_time: string | null;
  matched: boolean;
  duplicates: {
    backlog_entry_id: number;
    title: string;
    diffs: FieldDiff[];
  }[];
}

function toCsvPreviewItem(raw: CsvPreviewItemResponse): CsvPreviewItem {
  return {
    rowIndex: raw.row_index,
    title: raw.title,
    genre: raw.genre,
    platform: raw.platform,
    status: raw.status,
    owned: raw.owned,
    playtime: toNumber(raw.playtime),
    reviewStars: raw.review_stars ?? undefined,
    note: raw.note,
    review: raw.review,
    completedAt: raw.completed_at,
    imageLink: raw.image_link,
    description: raw.description,
    mainTime: toNumber(raw.main_time),
    mainPlusExtraTime: toNumber(raw.main_plus_extra_time),
    completionTime: toNumber(raw.completion_time),
    matched: raw.matched,
    duplicates: raw.duplicates.map((duplicate) => ({
      backlogEntryId: duplicate.backlog_entry_id,
      title: duplicate.title,
      diffs: duplicate.diffs,
    })),
  };
}

export async function previewCsvStream(
  content: string,
  config: ColumnConfig,
  onProgress: (progress: CsvImportProgress) => void,
): Promise<CsvPreviewItem[]> {
  const { response, error } = await apiClient.POST("/api/csv/preview/stream", {
    parseAs: "stream",
    body: toMatchCsvRequestBody(content, config),
  });
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to preview CSV import"));
  const items = await streamSse<CsvImportProgress, CsvPreviewItemResponse[]>(
    response,
    {
      onProgress,
    },
  );
  return items.map(toCsvPreviewItem);
}

export interface SubmitCsvEntry {
  title: string;
  genre: string;
  platform: string[];
  status: string;
  owned: boolean;
  playtime?: number;
  reviewStars?: number;
  note?: string | null;
  review?: string | null;
  completedAt?: string | null;
  imageLink?: string | null;
  description?: string | null;
  mainTime?: number;
  mainPlusExtraTime?: number;
  completionTime?: number;
}

export async function submitCsvStream(
  entries: SubmitCsvEntry[],
  onProgress: (progress: CsvImportProgress) => void,
): Promise<BacklogEntryData[]> {
  const { response, error } = await apiClient.POST("/api/csv/submit/stream", {
    parseAs: "stream",
    body: entries.map((entry) => ({
      title: entry.title,
      genre: entry.genre,
      platform: entry.platform,
      status: entry.status,
      owned: entry.owned,
      playtime: entry.playtime !== undefined ? String(entry.playtime) : null,
      review_stars: entry.reviewStars ?? null,
      note: entry.note ?? null,
      review: entry.review ?? null,
      completed_at: entry.completedAt ?? null,
      image_link: entry.imageLink ?? null,
      description: entry.description ?? null,
      main_time: entry.mainTime !== undefined ? String(entry.mainTime) : null,
      main_plus_extra_time:
        entry.mainPlusExtraTime !== undefined
          ? String(entry.mainPlusExtraTime)
          : null,
      completion_time:
        entry.completionTime !== undefined
          ? String(entry.completionTime)
          : null,
    })),
  });
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to submit CSV import"));
  const created = await streamSse<
    CsvImportProgress,
    components["schemas"]["BacklogEntryResponse"][]
  >(response, { onProgress });
  return created.map(toEntryData);
}
