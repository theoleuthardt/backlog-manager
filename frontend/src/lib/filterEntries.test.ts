import { describe, expect, it } from "vitest";
import type { BacklogEntryData } from "~/lib/api/backlog";
import {
  EMPTY_FILTERS,
  countActiveFilters,
  filterEntries,
  type EntryFilters,
} from "~/lib/filterEntries";

function entry(overrides: Partial<BacklogEntryData>): BacklogEntryData {
  return {
    id: 1,
    title: "Untitled",
    imageLink: "",
    imageAlt: "",
    genre: [],
    platform: [],
    status: "Not Started",
    owned: false,
    interest: 0,
    ...overrides,
  };
}

const withFilters = (overrides: Partial<EntryFilters>): EntryFilters => ({
  ...EMPTY_FILTERS,
  ...overrides,
});

const ids = (entries: BacklogEntryData[]) => entries.map((e) => e.id);

describe("filterEntries", () => {
  it("keeps every entry when no filter is active, including zero and very high values", () => {
    const entries = [
      entry({ id: 1, interest: 0, reviewStars: 0, playtime: 0 }),
      entry({ id: 2, interest: 10, reviewStars: 5, playtime: 900 }),
    ];

    expect(ids(filterEntries(entries, EMPTY_FILTERS))).toEqual([1, 2]);
  });

  it("matches the search text against the title, case-insensitively", () => {
    const entries = [
      entry({ id: 1, title: "Hollow Knight" }),
      entry({ id: 2, title: "Celeste" }),
    ];

    expect(
      ids(filterEntries(entries, withFilters({ search: "  KNIGHT " }))),
    ).toEqual([1]);
  });

  it("keeps entries that share at least one selected platform", () => {
    const entries = [
      entry({ id: 1, platform: ["PC", "Switch"] }),
      entry({ id: 2, platform: ["PS5"] }),
      entry({ id: 3, platform: [] }),
    ];

    expect(
      ids(
        filterEntries(entries, withFilters({ platforms: ["Switch", "Xbox"] })),
      ),
    ).toEqual([1]);
  });

  it("keeps entries that share at least one selected genre", () => {
    const entries = [
      entry({ id: 1, genre: ["RPG"] }),
      entry({ id: 2, genre: ["Puzzle", "Action"] }),
    ];

    expect(
      ids(filterEntries(entries, withFilters({ genres: ["Action"] }))),
    ).toEqual([2]);
  });

  it("keeps entries whose status is one of the selected statuses", () => {
    const entries = [
      entry({ id: 1, status: "Completed" }),
      entry({ id: 2, status: "Dropped" }),
    ];

    expect(
      ids(filterEntries(entries, withFilters({ statuses: ["Dropped"] }))),
    ).toEqual([2]);
  });

  it("drops unowned entries when ownedOnly is set", () => {
    const entries = [
      entry({ id: 1, owned: true }),
      entry({ id: 2, owned: false }),
    ];

    expect(
      ids(filterEntries(entries, withFilters({ ownedOnly: true }))),
    ).toEqual([1]);
  });

  it("applies an interest range inclusively", () => {
    const entries = [
      entry({ id: 1, interest: 2 }),
      entry({ id: 2, interest: 5 }),
      entry({ id: 3, interest: 8 }),
    ];

    expect(
      ids(filterEntries(entries, withFilters({ interest: [5, 8] }))),
    ).toEqual([2, 3]);
  });

  it("lets entries without a review through a review-stars range but filters rated ones", () => {
    const entries = [
      entry({ id: 1 }),
      entry({ id: 2, reviewStars: 2 }),
      entry({ id: 3, reviewStars: 5 }),
    ];

    expect(
      ids(filterEntries(entries, withFilters({ reviewStars: [4, 5] }))),
    ).toEqual([1, 3]);
  });

  it("applies playtime and the three HowLongToBeat ranges", () => {
    const entries = [
      entry({
        id: 1,
        playtime: 5,
        mainTime: 10,
        mainPlusExtraTime: 20,
        completionTime: 40,
      }),
      entry({
        id: 2,
        playtime: 50,
        mainTime: 60,
        mainPlusExtraTime: 90,
        completionTime: 150,
      }),
    ];

    expect(
      ids(filterEntries(entries, withFilters({ playtime: [0, 10] }))),
    ).toEqual([1]);
    expect(
      ids(filterEntries(entries, withFilters({ mainTime: [30, 100] }))),
    ).toEqual([2]);
    expect(
      ids(filterEntries(entries, withFilters({ mainPlusExtraTime: [0, 30] }))),
    ).toEqual([1]);
    expect(
      ids(filterEntries(entries, withFilters({ completionTime: [100, 200] }))),
    ).toEqual([2]);
  });

  it("combines all active filters with AND", () => {
    const entries = [
      entry({ id: 1, status: "Completed", owned: true, platform: ["PC"] }),
      entry({ id: 2, status: "Completed", owned: false, platform: ["PC"] }),
    ];

    const result = filterEntries(
      entries,
      withFilters({
        statuses: ["Completed"],
        ownedOnly: true,
        platforms: ["PC"],
      }),
    );

    expect(ids(result)).toEqual([1]);
  });
});

describe("countActiveFilters", () => {
  it("is zero for the empty filter set", () => {
    expect(countActiveFilters(EMPTY_FILTERS)).toBe(0);
  });

  it("counts each active filter once and ignores the search text", () => {
    const filters = withFilters({
      search: "zelda",
      platforms: ["PC", "Switch"],
      ownedOnly: true,
      playtime: [0, 10],
    });

    expect(countActiveFilters(filters)).toBe(3);
  });
});
