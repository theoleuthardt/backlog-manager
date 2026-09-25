import type { BacklogEntryData } from "~/lib/api/backlog";

/**
 * `null` means "no restriction" - a range is only active once the user
 * has moved its slider, so entries outside the visible slider bounds
 * (e.g. a 900h playtime) are never hidden by an untouched filter.
 */
export type NumericRange = readonly [number, number] | null;

export interface EntryFilters {
  search: string;
  platforms: readonly string[];
  genres: readonly string[];
  statuses: readonly string[];
  ownedOnly: boolean;
  interest: NumericRange;
  reviewStars: NumericRange;
  playtime: NumericRange;
  mainTime: NumericRange;
  mainPlusExtraTime: NumericRange;
  completionTime: NumericRange;
}

export const EMPTY_FILTERS: EntryFilters = {
  search: "",
  platforms: [],
  genres: [],
  statuses: [],
  ownedOnly: false,
  interest: null,
  reviewStars: null,
  playtime: null,
  mainTime: null,
  mainPlusExtraTime: null,
  completionTime: null,
};

const RANGE_KEYS = [
  "interest",
  "reviewStars",
  "playtime",
  "mainTime",
  "mainPlusExtraTime",
  "completionTime",
] as const;

function withinRange(value: number | undefined, range: NumericRange): boolean {
  if (range === null || value === undefined) return true;
  return value >= range[0] && value <= range[1];
}

function sharesAny(values: readonly string[], selected: readonly string[]) {
  return values.some((value) => selected.includes(value));
}

export function filterEntries(
  entries: readonly BacklogEntryData[],
  filters: EntryFilters,
): BacklogEntryData[] {
  const search = filters.search.trim().toLowerCase();
  return entries.filter((entry) => {
    if (search && !entry.title.toLowerCase().includes(search)) return false;
    if (
      filters.platforms.length > 0 &&
      !sharesAny(entry.platform, filters.platforms)
    )
      return false;
    if (filters.genres.length > 0 && !sharesAny(entry.genre, filters.genres))
      return false;
    if (filters.statuses.length > 0 && !filters.statuses.includes(entry.status))
      return false;
    if (filters.ownedOnly && !entry.owned) return false;
    return RANGE_KEYS.every((key) => withinRange(entry[key], filters[key]));
  });
}

/**
 * Number of active filter groups, shown as a badge on the sidebar
 * toggle. The search text is excluded because it has its own always
 * visible input in the navbar.
 */
export function countActiveFilters(filters: EntryFilters): number {
  const listFilters = [filters.platforms, filters.genres, filters.statuses];
  const active =
    listFilters.filter((list) => list.length > 0).length +
    RANGE_KEYS.filter((key) => filters[key] !== null).length;
  return active + (filters.ownedOnly ? 1 : 0);
}
