import { describe, expect, it } from "vitest";
import { diffEntryForm, type EntryForm } from "~/lib/entryChanges";
import type { BacklogEntryProps } from "~/app/types/backlog";

const entry: BacklogEntryProps = {
  id: 1,
  title: "Celeste",
  imageLink: "https://example.com/a.jpg",
  playtime: 4,
  genre: ["Platformer", "Indie"],
  platform: ["PC"],
  status: "Not Started",
  owned: true,
  interest: 5,
  reviewStars: 0,
  review: "",
  note: "",
};

const unchanged: EntryForm = {
  imageLink: "https://example.com/a.jpg",
  playtime: 4,
  genre: "Platformer, Indie",
  platform: "PC",
  status: "Not Started",
  owned: true,
  interest: 5,
  reviewStars: 0,
  review: "",
  note: "",
};

describe("diffEntryForm", () => {
  it("returns no changes for an untouched form", () => {
    expect(diffEntryForm(unchanged, entry)).toEqual({});
  });

  it("only includes the fields that differ", () => {
    expect(
      diffEntryForm(
        { ...unchanged, status: "Completed", note: "great" },
        entry,
      ),
    ).toEqual({ status: "Completed", note: "great" });
  });

  it("splits genre and platform lists", () => {
    expect(
      diffEntryForm(
        { ...unchanged, genre: "RPG,  Action", platform: "PC, Switch" },
        entry,
      ),
    ).toEqual({ genre: ["RPG", "Action"], platform: ["PC", "Switch"] });
  });

  it("ignores an unset playtime", () => {
    expect(diffEntryForm({ ...unchanged, playtime: undefined }, entry)).toEqual(
      {},
    );
  });

  it("treats missing entry values as their form defaults", () => {
    const bare: BacklogEntryProps = {
      id: 2,
      title: "Bare",
      imageLink: "",
    };
    expect(
      diffEntryForm(
        {
          imageLink: "",
          playtime: undefined,
          genre: "",
          platform: "",
          status: "",
          owned: false,
          interest: 0,
          reviewStars: 0,
          review: "",
          note: "",
        },
        bare,
      ),
    ).toEqual({});
  });
});
