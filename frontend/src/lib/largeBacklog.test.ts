import { describe, expect, it } from "vitest";
import type { BacklogEntryData } from "~/lib/api/backlog";
import { EMPTY_FILTERS, filterEntries } from "~/lib/filterEntries";
import { groupEntriesByStatus } from "~/lib/groupEntries";
import { sortEntries } from "~/lib/sortEntries";

const STATUSES = ["Not Started", "Playing", "Completed", "Dropped"] as const;
const ENTRY_COUNT = 10_000;
const TIME_BUDGET_MS = 500;

function largeBacklog(): BacklogEntryData[] {
  return Array.from({ length: ENTRY_COUNT }, (_, id) => ({
    id,
    title: `Game ${(id * 7919) % ENTRY_COUNT}`,
    imageLink: "",
    imageAlt: "",
    genre: ["Action"],
    platform: ["PC"],
    status: STATUSES[id % STATUSES.length]!,
    owned: id % 2 === 0,
    interest: id % 5,
  }));
}

function timed(run: () => void): number {
  const start = performance.now();
  run();
  return performance.now() - start;
}

describe("dashboard logic with a large backlog", () => {
  const entries = largeBacklog();

  it("filters 10k entries within the time budget", () => {
    let result: BacklogEntryData[] = [];
    const elapsed = timed(() => {
      result = filterEntries(entries, { ...EMPTY_FILTERS, search: "game 12" });
    });

    expect(result.length).toBeGreaterThan(0);
    expect(elapsed).toBeLessThan(TIME_BUDGET_MS);
  });

  it("sorts 10k entries within the time budget", () => {
    let result: BacklogEntryData[] = [];
    const elapsed = timed(() => {
      result = sortEntries(entries, {
        sortBy: "status",
        direction: "asc",
        statusOrder: STATUSES,
      });
    });

    expect(result).toHaveLength(ENTRY_COUNT);
    expect(elapsed).toBeLessThan(TIME_BUDGET_MS);
  });

  it("groups 10k entries by status within the time budget", () => {
    let groups: ReturnType<typeof groupEntriesByStatus> = [];
    const elapsed = timed(() => {
      groups = groupEntriesByStatus(entries, STATUSES);
    });

    expect(groups.reduce((sum, g) => sum + g.entries.length, 0)).toBe(
      ENTRY_COUNT,
    );
    expect(elapsed).toBeLessThan(TIME_BUDGET_MS);
  });
});
