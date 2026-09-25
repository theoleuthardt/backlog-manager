import { describe, expect, it } from "vitest";
import type { BacklogEntryData } from "~/lib/api/backlog";
import {
  groupEntriesByStatus,
  groupLabelFor,
  groupSortedEntries,
} from "~/lib/groupEntries";

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

function game(overrides: Partial<BacklogEntryData>): BacklogEntryData {
  return { ...entry(1, "Not Started"), ...overrides };
}

describe("groupLabelFor", () => {
  it("labels by first platform or a fallback", () => {
    expect(
      groupLabelFor(game({ platform: ["PC", "Switch"] }), "platform"),
    ).toBe("PC");
    expect(groupLabelFor(game({ platform: [] }), "platform")).toBe(
      "No platform",
    );
  });

  it("labels by first genre or a fallback", () => {
    expect(groupLabelFor(game({ genre: ["RPG", "Action"] }), "genre")).toBe(
      "RPG",
    );
    expect(groupLabelFor(game({ genre: [] }), "genre")).toBe("No genre");
  });

  it("labels by category name or Uncategorized", () => {
    const categories = new Map([[7, "Arcade"]]);

    expect(groupLabelFor(game({ id: 7 }), "category", categories)).toBe(
      "Arcade",
    );
    expect(groupLabelFor(game({ id: 8 }), "category", categories)).toBe(
      "Uncategorized",
    );
  });

  it("labels by interest level", () => {
    expect(groupLabelFor(game({ interest: 9 }), "interest")).toBe(
      "Interest 9/10",
    );
  });

  it("labels review stars, treating 0 and missing as Unreviewed", () => {
    expect(groupLabelFor(game({ reviewStars: 4 }), "review_stars")).toBe(
      "4 stars",
    );
    expect(groupLabelFor(game({ reviewStars: 1 }), "review_stars")).toBe(
      "1 star",
    );
    expect(groupLabelFor(game({ reviewStars: 0 }), "review_stars")).toBe(
      "Unreviewed",
    );
    expect(groupLabelFor(game({}), "review_stars")).toBe("Unreviewed");
  });

  it.each([
    [undefined, "Not played"],
    [0, "Not played"],
    [5, "Under 10h"],
    [10, "10-50h"],
    [49, "10-50h"],
    [50, "50-100h"],
    [100, "100h or more"],
  ])("buckets %s hours of playtime as %s", (playtime, label) => {
    expect(groupLabelFor(game({ playtime }), "playtime")).toBe(label);
  });
});

describe("groupSortedEntries", () => {
  it("groups by label in order of first appearance and merges non-adjacent matches", () => {
    const sorted = [
      game({ id: 1, reviewStars: 0 }),
      game({ id: 2, reviewStars: 3 }),
      game({ id: 3 }),
    ];

    const groups = groupSortedEntries(sorted, "review_stars");

    expect(groups.map((g) => g.label)).toEqual(["Unreviewed", "3 stars"]);
    expect(groups[0]?.entries.map((e) => e.id)).toEqual([1, 3]);
  });
});
