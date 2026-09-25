import { describe, expect, it } from "vitest";
import type { BacklogEntryData } from "~/lib/api/backlog";
import {
  defaultDirectionFor,
  isSortOption,
  sortEntries,
  type SortOption,
} from "~/lib/sortEntries";

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

const titles = (entries: BacklogEntryData[]) => entries.map((e) => e.title);

const STATUS_ORDER = [
  "Not Started",
  "In Progress",
  "Completed",
  "On Hold",
  "Dropped",
];

describe("sortEntries", () => {
  it("orders by status following the given status order, then title", () => {
    const entries = [
      entry({ id: 1, title: "Zelda", status: "Completed" }),
      entry({ id: 2, title: "Alpha", status: "Not Started" }),
      entry({ id: 3, title: "Bravo", status: "Completed" }),
      entry({ id: 4, title: "Doom", status: "In Progress" }),
    ];

    const sorted = sortEntries(entries, {
      sortBy: "status",
      direction: "asc",
      statusOrder: STATUS_ORDER,
    });

    expect(titles(sorted)).toEqual(["Alpha", "Doom", "Bravo", "Zelda"]);
  });

  it("places unknown statuses after every known one", () => {
    const entries = [
      entry({ id: 1, title: "Custom", status: "Co-Op Night" }),
      entry({ id: 2, title: "Known", status: "Dropped" }),
    ];

    const sorted = sortEntries(entries, {
      sortBy: "status",
      direction: "asc",
      statusOrder: STATUS_ORDER,
    });

    expect(titles(sorted)).toEqual(["Known", "Custom"]);
  });

  it("reverses status order when descending", () => {
    const entries = [
      entry({ id: 1, title: "A", status: "Not Started" }),
      entry({ id: 2, title: "B", status: "Dropped" }),
    ];

    const sorted = sortEntries(entries, {
      sortBy: "status",
      direction: "desc",
      statusOrder: STATUS_ORDER,
    });

    expect(titles(sorted)).toEqual(["B", "A"]);
  });

  it("sorts playtime numerically and keeps entries without playtime last in both directions", () => {
    const entries = [
      entry({ id: 1, title: "Ten", playtime: 10 }),
      entry({ id: 2, title: "None" }),
      entry({ id: 3, title: "Hundred", playtime: 100 }),
      entry({ id: 4, title: "Two", playtime: 2 }),
    ];

    const asc = sortEntries(entries, {
      sortBy: "playtime",
      direction: "asc",
      statusOrder: STATUS_ORDER,
    });
    const desc = sortEntries(entries, {
      sortBy: "playtime",
      direction: "desc",
      statusOrder: STATUS_ORDER,
    });

    expect(titles(asc)).toEqual(["Two", "Ten", "Hundred", "None"]);
    expect(titles(desc)).toEqual(["Hundred", "Ten", "Two", "None"]);
  });

  it("sorts by interest level", () => {
    const entries = [
      entry({ id: 1, title: "Low", interest: 2 }),
      entry({ id: 2, title: "High", interest: 9 }),
    ];

    const sorted = sortEntries(entries, {
      sortBy: "interest",
      direction: "desc",
      statusOrder: STATUS_ORDER,
    });

    expect(titles(sorted)).toEqual(["High", "Low"]);
  });

  it("sorts by review stars with unreviewed entries last", () => {
    const entries = [
      entry({ id: 1, title: "Unreviewed" }),
      entry({ id: 2, title: "Three", reviewStars: 3 }),
      entry({ id: 3, title: "Five", reviewStars: 5 }),
    ];

    const sorted = sortEntries(entries, {
      sortBy: "review_stars",
      direction: "desc",
      statusOrder: STATUS_ORDER,
    });

    expect(titles(sorted)).toEqual(["Five", "Three", "Unreviewed"]);
  });

  it("sorts by first genre alphabetically, empty genre last", () => {
    const entries = [
      entry({ id: 1, title: "NoGenre" }),
      entry({ id: 2, title: "Rpg", genre: ["RPG", "Action"] }),
      entry({ id: 3, title: "Adventure", genre: ["Adventure"] }),
    ];

    const sorted = sortEntries(entries, {
      sortBy: "genre",
      direction: "asc",
      statusOrder: STATUS_ORDER,
    });

    expect(titles(sorted)).toEqual(["Adventure", "Rpg", "NoGenre"]);
  });

  it("sorts by first platform alphabetically, empty platform last", () => {
    const entries = [
      entry({ id: 1, title: "NoPlatform" }),
      entry({ id: 2, title: "Switch", platform: ["Switch"] }),
      entry({ id: 3, title: "Pc", platform: ["PC", "Switch"] }),
    ];

    const sorted = sortEntries(entries, {
      sortBy: "platform",
      direction: "asc",
      statusOrder: STATUS_ORDER,
    });

    expect(titles(sorted)).toEqual(["Pc", "Switch", "NoPlatform"]);
  });

  it("sorts by category name with uncategorized entries last", () => {
    const entries = [
      entry({ id: 1, title: "Loose" }),
      entry({ id: 2, title: "InZ" }),
      entry({ id: 3, title: "InA" }),
    ];

    const sorted = sortEntries(entries, {
      sortBy: "category",
      direction: "asc",
      statusOrder: STATUS_ORDER,
      categoryByEntryId: new Map([
        [2, "Zombies"],
        [3, "Arcade"],
      ]),
    });

    expect(titles(sorted)).toEqual(["InA", "InZ", "Loose"]);
  });

  it("does not mutate the input array", () => {
    const entries = [
      entry({ id: 1, title: "B", interest: 1 }),
      entry({ id: 2, title: "A", interest: 5 }),
    ];
    const snapshot = [...entries];

    sortEntries(entries, {
      sortBy: "interest",
      direction: "desc",
      statusOrder: STATUS_ORDER,
    });

    expect(entries).toEqual(snapshot);
  });
});

describe("defaultDirectionFor", () => {
  it.each<[SortOption, "asc" | "desc"]>([
    ["status", "asc"],
    ["category", "asc"],
    ["genre", "asc"],
    ["platform", "asc"],
    ["playtime", "desc"],
    ["interest", "desc"],
    ["review_stars", "desc"],
  ])("uses %s -> %s", (option, direction) => {
    expect(defaultDirectionFor(option)).toBe(direction);
  });
});

describe("isSortOption", () => {
  it("accepts known options and rejects everything else", () => {
    expect(isSortOption("review_stars")).toBe(true);
    expect(isSortOption("random")).toBe(false);
  });
});
