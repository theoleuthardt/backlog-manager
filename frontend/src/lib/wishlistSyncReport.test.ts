import { describe, expect, it } from "vitest";
import {
  hasWishlistChanges,
  wishlistDiffRows,
  wishlistSyncSummary,
  type WishlistSyncReport,
} from "~/lib/wishlistSyncReport";

const report: WishlistSyncReport = {
  since: "2026-10-09T08:00:00",
  added: [
    { steamAppId: 620, title: "Portal 2" },
    { steamAppId: 730, title: "Counter-Strike 2" },
  ],
  removed: [{ steamAppId: 10, title: "Counter-Strike" }],
};

describe("hasWishlistChanges", () => {
  it("is true when a game was added or removed", () => {
    expect(hasWishlistChanges(report)).toBe(true);
    expect(hasWishlistChanges({ added: [], removed: report.removed })).toBe(
      true,
    );
  });

  it("is false for an empty report", () => {
    expect(hasWishlistChanges({ added: [], removed: [] })).toBe(false);
    expect(hasWishlistChanges(null)).toBe(false);
  });
});

describe("wishlistDiffRows", () => {
  it("lists the removed games as minus lines before the added plus lines", () => {
    expect(wishlistDiffRows(report)).toEqual([
      { sign: "-", steamAppId: 10, title: "Counter-Strike" },
      { sign: "+", steamAppId: 620, title: "Portal 2" },
      { sign: "+", steamAppId: 730, title: "Counter-Strike 2" },
    ]);
  });
});

describe("wishlistSyncSummary", () => {
  it("counts both sides with singular and plural", () => {
    expect(wishlistSyncSummary(report)).toBe(
      "2 games added, 1 game removed since 9 Oct 2026",
    );
  });

  it("leaves out the side without changes and the unknown date", () => {
    expect(
      wishlistSyncSummary({
        added: [{ steamAppId: 1, title: "One" }],
        removed: [],
      }),
    ).toBe("1 game added");
  });
});
