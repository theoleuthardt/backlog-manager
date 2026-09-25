import type { BacklogEntryData } from "~/lib/api/backlog";

export const SORT_OPTIONS = [
  { value: "status", label: "Status" },
  { value: "category", label: "Category" },
  { value: "genre", label: "Genre" },
  { value: "playtime", label: "Playtime" },
  { value: "platform", label: "Platform" },
  { value: "interest", label: "Interest level" },
  { value: "review_stars", label: "Review stars" },
] as const;

export type SortOption = (typeof SORT_OPTIONS)[number]["value"];
export type SortDirection = "asc" | "desc";

export const DEFAULT_SORT: SortOption = "status";

export function isSortOption(value: string): value is SortOption {
  return SORT_OPTIONS.some((option) => option.value === value);
}

export function defaultDirectionFor(sortBy: SortOption): SortDirection {
  switch (sortBy) {
    case "playtime":
    case "interest":
    case "review_stars":
      return "desc";
    default:
      return "asc";
  }
}

export interface SortConfig {
  sortBy: SortOption;
  direction: SortDirection;
  statusOrder: readonly string[];
  categoryByEntryId?: ReadonlyMap<number, string>;
}

type SortKey = number | string | undefined;

function keyFor(entry: BacklogEntryData, config: SortConfig): SortKey {
  switch (config.sortBy) {
    case "status": {
      const index = config.statusOrder.indexOf(entry.status);
      return index === -1 ? config.statusOrder.length : index;
    }
    case "category":
      return config.categoryByEntryId?.get(entry.id);
    case "genre":
      return entry.genre[0];
    case "platform":
      return entry.platform[0];
    case "playtime":
      return entry.playtime;
    case "interest":
      return entry.interest;
    case "review_stars":
      return entry.reviewStars;
  }
}

function compareKeys(a: NonNullable<SortKey>, b: NonNullable<SortKey>): number {
  if (typeof a === "number" && typeof b === "number") return a - b;
  return String(a).localeCompare(String(b));
}

/**
 * Returns a sorted copy of `entries`. Entries missing the sort key
 * (no playtime, no genre, uncategorized, ...) always sort last,
 * whichever direction is chosen; ties fall back to the title so the
 * order is stable and predictable.
 */
export function sortEntries(
  entries: readonly BacklogEntryData[],
  config: SortConfig,
): BacklogEntryData[] {
  const sign = config.direction === "asc" ? 1 : -1;
  return [...entries].sort((a, b) => {
    const keyA = keyFor(a, config);
    const keyB = keyFor(b, config);
    if (keyA === undefined && keyB !== undefined) return 1;
    if (keyA !== undefined && keyB === undefined) return -1;
    if (keyA !== undefined && keyB !== undefined) {
      const result = compareKeys(keyA, keyB);
      if (result !== 0) return result * sign;
    }
    return a.title.localeCompare(b.title);
  });
}
