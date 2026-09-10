import { apiClient, apiErrorMessage } from "./client";
import type { components } from "./schema";

export type BacklogStatus =
  | "Not Started"
  | "In Progress"
  | "Completed"
  | "On Hold"
  | "Dropped";

export interface BacklogEntryData {
  id: number;
  title: string;
  imageLink: string;
  imageAlt: string;
  genre: string[];
  platform: string[];
  status: string;
  owned: boolean;
  interest: number;
  reviewStars?: number;
  review?: string;
  note?: string;
  mainTime?: number;
  mainPlusExtraTime?: number;
  completionTime?: number;
  playtime?: number;
  steamAppId?: number;
}

/**
 * `status` is a plain string, not `BacklogStatus`, because the backend
 * doesn't enforce an enum here - CSV imports in particular can carry an
 * arbitrary status value from the source file. `BacklogStatus` stays
 * around for call sites backed by an actual status dropdown
 * (CreationToolForm, BacklogEntry).
 */
export interface CreateBacklogEntryInput {
  title: string;
  genre: string[];
  platform: string[];
  status: string;
  owned: boolean;
  interest: number;
  imageLink?: string;
  mainTime?: number;
  mainPlusExtraTime?: number;
  completionTime?: number;
  playtime?: number;
  steamAppId?: number;
  reviewStars?: number;
  review?: string;
  note?: string;
}

export interface UpdateBacklogEntryInput {
  title?: string;
  genre?: string[];
  platform?: string[];
  status?: string;
  owned?: boolean;
  interest?: number;
  imageLink?: string;
  mainTime?: number;
  mainPlusExtraTime?: number;
  completionTime?: number;
  playtime?: number;
  steamAppId?: number | null;
  reviewStars?: number;
  review?: string;
  note?: string;
}

export interface CategoryData {
  id: number;
  name: string;
  color: string;
  description: string | null;
}

function toNumber(value: string | null | undefined): number | undefined {
  if (value === null || value === undefined) return undefined;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

export function toEntryData(
  entry: components["schemas"]["BacklogEntryResponse"],
): BacklogEntryData {
  return {
    id: entry.id,
    title: entry.title,
    imageLink: entry.image_link ?? "",
    imageAlt: entry.title,
    genre: entry.genre,
    platform: entry.platform,
    status: entry.status,
    owned: entry.owned,
    interest: entry.interest,
    reviewStars: entry.review_stars ?? undefined,
    review: entry.review ?? undefined,
    note: entry.note ?? undefined,
    mainTime: toNumber(entry.main_time),
    mainPlusExtraTime: toNumber(entry.main_plus_extra_time),
    completionTime: toNumber(entry.completion_time),
    playtime: toNumber(entry.playtime),
    steamAppId: entry.steam_app_id ?? undefined,
  };
}

function toCategoryData(
  category: components["schemas"]["CategoryResponse"],
): CategoryData {
  return {
    id: category.id,
    name: category.name,
    color: category.color,
    description: category.description ?? null,
  };
}

export async function getEntries(): Promise<BacklogEntryData[]> {
  const { data, error } = await apiClient.GET("/api/backlog/entries");
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to load backlog entries"));
  return data.map(toEntryData);
}

export async function getEntryById(entryId: number): Promise<BacklogEntryData> {
  const { data, error } = await apiClient.GET(
    "/api/backlog/entries/{entry_id}",
    {
      params: { path: { entry_id: entryId } },
    },
  );
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to load backlog entry"));
  return toEntryData(data);
}

export async function getEntriesByStatus(
  status: string,
): Promise<BacklogEntryData[]> {
  const { data, error } = await apiClient.GET("/api/backlog/entries", {
    params: { query: { status } },
  });
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to load backlog entries"));
  return data.map(toEntryData);
}

export async function createEntry(
  input: CreateBacklogEntryInput,
): Promise<BacklogEntryData> {
  const { data, error } = await apiClient.POST("/api/backlog/entries", {
    body: {
      title: input.title,
      genre: input.genre,
      platform: input.platform,
      status: input.status,
      owned: input.owned,
      interest: input.interest,
      image_link: input.imageLink,
      main_time: input.mainTime?.toString(),
      main_plus_extra_time: input.mainPlusExtraTime?.toString(),
      completion_time: input.completionTime?.toString(),
      playtime: input.playtime?.toString(),
      steam_app_id: input.steamAppId,
      review_stars: input.reviewStars,
      review: input.review,
      note: input.note,
    },
  });
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to create backlog entry"));
  return toEntryData(data);
}

export async function updateEntry(
  entryId: number,
  changes: UpdateBacklogEntryInput,
): Promise<BacklogEntryData> {
  const { data, error } = await apiClient.PUT(
    "/api/backlog/entries/{entry_id}",
    {
      params: { path: { entry_id: entryId } },
      body: {
        title: changes.title,
        genre: changes.genre,
        platform: changes.platform,
        status: changes.status,
        owned: changes.owned,
        interest: changes.interest,
        image_link: changes.imageLink,
        main_time: changes.mainTime?.toString(),
        main_plus_extra_time: changes.mainPlusExtraTime?.toString(),
        completion_time: changes.completionTime?.toString(),
        playtime: changes.playtime?.toString(),
        steam_app_id: changes.steamAppId,
        review_stars: changes.reviewStars,
        review: changes.review,
        note: changes.note,
      },
    },
  );
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to update backlog entry"));
  return toEntryData(data);
}

export async function deleteEntry(entryId: number): Promise<void> {
  const { error } = await apiClient.DELETE("/api/backlog/entries/{entry_id}", {
    params: { path: { entry_id: entryId } },
  });
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to delete backlog entry"));
}

export async function getCategories(): Promise<CategoryData[]> {
  const { data, error } = await apiClient.GET("/api/backlog/categories");
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to load categories"));
  return data.map(toCategoryData);
}

export async function createCategory(input: {
  categoryName: string;
  color?: string;
  description?: string;
}): Promise<CategoryData> {
  const { data, error } = await apiClient.POST("/api/backlog/categories", {
    body: {
      category_name: input.categoryName,
      color: input.color,
      description: input.description,
    },
  });
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to create category"));
  return toCategoryData(data);
}

export async function updateCategory(
  categoryId: number,
  changes: { categoryName?: string; color?: string; description?: string },
): Promise<CategoryData> {
  const { data, error } = await apiClient.PUT(
    "/api/backlog/categories/{category_id}",
    {
      params: { path: { category_id: categoryId } },
      body: {
        category_name: changes.categoryName,
        color: changes.color,
        description: changes.description,
      },
    },
  );
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to update category"));
  return toCategoryData(data);
}

export async function deleteCategory(categoryId: number): Promise<void> {
  const { error } = await apiClient.DELETE(
    "/api/backlog/categories/{category_id}",
    {
      params: { path: { category_id: categoryId } },
    },
  );
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to delete category"));
}

export async function getCategoriesForEntry(
  entryId: number,
): Promise<CategoryData[]> {
  const { data, error } = await apiClient.GET(
    "/api/backlog/entries/{entry_id}/categories",
    { params: { path: { entry_id: entryId } } },
  );
  if (error)
    throw new Error(
      apiErrorMessage(error, "Failed to load categories for entry"),
    );
  return data.map(toCategoryData);
}

export async function getEntriesForCategory(
  categoryId: number,
): Promise<BacklogEntryData[]> {
  const { data, error } = await apiClient.GET(
    "/api/backlog/categories/{category_id}/entries",
    { params: { path: { category_id: categoryId } } },
  );
  if (error)
    throw new Error(
      apiErrorMessage(error, "Failed to load entries for category"),
    );
  return data.map(toEntryData);
}

export async function addCategoryToEntry(
  entryId: number,
  categoryId: number,
): Promise<void> {
  const { error } = await apiClient.POST(
    "/api/backlog/entries/{entry_id}/categories/{category_id}",
    { params: { path: { entry_id: entryId, category_id: categoryId } } },
  );
  if (error)
    throw new Error(apiErrorMessage(error, "Failed to add category to entry"));
}

export async function removeCategoryFromEntry(
  entryId: number,
  categoryId: number,
): Promise<void> {
  const { error } = await apiClient.DELETE(
    "/api/backlog/entries/{entry_id}/categories/{category_id}",
    { params: { path: { entry_id: entryId, category_id: categoryId } } },
  );
  if (error)
    throw new Error(
      apiErrorMessage(error, "Failed to remove category from entry"),
    );
}
