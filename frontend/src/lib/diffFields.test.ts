import { describe, expect, it } from "vitest";
import { computeFieldDiffs } from "~/lib/diffFields";

const baseline = {
  genre: ["Platformer"],
  platform: ["PC"],
  status: "Completed",
  owned: true,
  playtime: 12.5,
  reviewStars: 8,
  note: "Great game",
};

describe("computeFieldDiffs", () => {
  it("returns no diffs when both sides are identical", () => {
    expect(computeFieldDiffs(baseline, baseline)).toEqual([]);
  });

  it("reports only the fields that differ", () => {
    const proposed = { ...baseline, status: "In Progress", owned: false };

    const diffs = computeFieldDiffs(baseline, proposed);

    expect(diffs).toEqual([
      { field: "status", existing: "Completed", proposed: "In Progress" },
      { field: "owned", existing: "Yes", proposed: "No" },
    ]);
  });

  it("joins genre and platform arrays for comparison and display", () => {
    const proposed = { ...baseline, genre: ["Platformer", "Metroidvania"] };

    const diffs = computeFieldDiffs(baseline, proposed);

    expect(diffs).toEqual([
      {
        field: "genre",
        existing: "Platformer",
        proposed: "Platformer, Metroidvania",
      },
    ]);
  });

  it("treats undefined playtime/reviewStars/note as empty rather than 'undefined'", () => {
    const existing = { ...baseline, playtime: undefined, reviewStars: undefined, note: undefined };
    const proposed = baseline;

    const diffs = computeFieldDiffs(existing, proposed);

    expect(diffs).toEqual([
      { field: "playtime", existing: "", proposed: "12.5" },
      { field: "review_stars", existing: "", proposed: "8" },
      { field: "note", existing: "", proposed: "Great game" },
    ]);
  });
});
