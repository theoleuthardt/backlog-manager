import { describe, expect, it } from "vitest";
import { splitList } from "~/lib/splitList";

describe("splitList", () => {
  it("splits on commas and trims every item", () => {
    expect(splitList("RPG, Indie ,Platformer")).toEqual([
      "RPG",
      "Indie",
      "Platformer",
    ]);
  });

  it("drops empty items", () => {
    expect(splitList("RPG,, ,Indie,")).toEqual(["RPG", "Indie"]);
  });

  it("returns an empty list for an empty or blank string", () => {
    expect(splitList("")).toEqual([]);
    expect(splitList("   ")).toEqual([]);
  });

  it("keeps a single item as is", () => {
    expect(splitList("PC")).toEqual(["PC"]);
  });
});
