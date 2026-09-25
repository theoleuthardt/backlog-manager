import type { BacklogEntryData } from "~/lib/api/backlog";

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
