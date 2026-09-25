import type { BacklogEntryData } from "~/lib/api/backlog";
import type { SortOption } from "~/lib/sortEntries";

export interface StatusGroup {
  status: string;
  entries: BacklogEntryData[];
}

/**
 * Splits `entries` into one group per status. Every status in
 * `statusOrder` gets a group even when it has no entries, so the
 * dashboard can still show it as a drag-and-drop target; statuses
 * that only occur on entries (e.g. imported from CSV) are appended
 * after the known ones.
 */
export function groupEntriesByStatus(
  entries: readonly BacklogEntryData[],
  statusOrder: readonly string[],
): StatusGroup[] {
  const groups = new Map<string, BacklogEntryData[]>(
    statusOrder.map((status) => [status, []]),
  );
  for (const entry of entries) {
    const group = groups.get(entry.status);
    if (group) group.push(entry);
    else groups.set(entry.status, [entry]);
  }
  return Array.from(groups, ([status, groupEntries]) => ({
    status,
    entries: groupEntries,
  }));
}

export interface LabelGroup {
  label: string;
  entries: BacklogEntryData[];
}

function playtimeBucket(playtime: number | undefined): string {
  if (!playtime) return "Not played";
  if (playtime < 10) return "Under 10h";
  if (playtime < 50) return "10-50h";
  if (playtime < 100) return "50-100h";
  return "100h or more";
}

/**
 * Headline an entry falls under for the given sort option. Uses the
 * same key the sort uses (first genre, first platform, ...), so
 * entries that sort next to each other land in the same group.
 */
export function groupLabelFor(
  entry: BacklogEntryData,
  sortBy: SortOption,
  categoryByEntryId?: ReadonlyMap<number, string>,
): string {
  switch (sortBy) {
    case "status":
      return entry.status;
    case "category":
      return categoryByEntryId?.get(entry.id) ?? "Uncategorized";
    case "genre":
      return entry.genre[0] ?? "No genre";
    case "platform":
      return entry.platform[0] ?? "No platform";
    case "interest":
      return `Interest ${entry.interest}/10`;
    case "review_stars":
      if (!entry.reviewStars) return "Unreviewed";
      return `${entry.reviewStars} ${entry.reviewStars === 1 ? "star" : "stars"}`;
    case "playtime":
      return playtimeBucket(entry.playtime);
  }
}

/**
 * Groups already-sorted entries under their headlines, keeping the
 * order in which each label first appears (so the sort direction also
 * orders the groups). Matching entries that are not adjacent - e.g.
 * review stars 0 and "no review" - end up in the same group.
 */
export function groupSortedEntries(
  sorted: readonly BacklogEntryData[],
  sortBy: SortOption,
  categoryByEntryId?: ReadonlyMap<number, string>,
): LabelGroup[] {
  const groups = new Map<string, BacklogEntryData[]>();
  for (const entry of sorted) {
    const label = groupLabelFor(entry, sortBy, categoryByEntryId);
    const group = groups.get(label);
    if (group) group.push(entry);
    else groups.set(label, [entry]);
  }
  return Array.from(groups, ([label, entries]) => ({ label, entries }));
}
