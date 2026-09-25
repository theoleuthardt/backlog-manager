import { describe, expect, it } from "vitest";
import type { BacklogEntryData } from "~/lib/api/backlog";
import { groupEntriesByStatus } from "~/lib/groupEntries";

function entry(id: number, status: string): BacklogEntryData {
  return {
    id,
    title: `Game ${id}`,
    imageLink: "",
    imageAlt: "",
    genre: [],
    platform: [],
    status,
    owned: false,
    interest: 0,
  };
}

describe("groupEntriesByStatus", () => {
  it("returns one group per status in the given order, keeping entry order inside each group", () => {
    const groups = groupEntriesByStatus(
      [entry(1, "Completed"), entry(2, "Not Started"), entry(3, "Completed")],
      ["Not Started", "Completed"],
    );

    expect(groups.map((g) => g.status)).toEqual(["Not Started", "Completed"]);
    expect(groups[1]?.entries.map((e) => e.id)).toEqual([1, 3]);
  });

  it("keeps known statuses without entries as empty groups so they stay drop targets", () => {
    const groups = groupEntriesByStatus(
      [entry(1, "Completed")],
      ["Not Started", "Completed"],
    );

    expect(groups[0]).toEqual({ status: "Not Started", entries: [] });
  });

  it("appends groups for statuses missing from the given order", () => {
    const groups = groupEntriesByStatus(
      [entry(1, "Completed"), entry(2, "Co-Op Night")],
      ["Completed"],
    );

    expect(groups.map((g) => g.status)).toEqual(["Completed", "Co-Op Night"]);
  });
});
