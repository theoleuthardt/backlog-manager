import { describe, expect, it } from "vitest";
import {
  skippedWishlistMessage,
  wishlistImportDate,
} from "~/lib/steamWishlist";

describe("wishlistImportDate", () => {
  it("is null while the wishlist was never imported", () => {
    expect(wishlistImportDate(undefined)).toBeNull();
    expect(wishlistImportDate("")).toBeNull();
  });

  it("formats the date of the first import", () => {
    expect(wishlistImportDate("2026-10-10T09:30:00")).toBe("10 Oct 2026");
  });

  it("reads a timestamp that carries its offset", () => {
    expect(wishlistImportDate("2026-01-02T23:30:00Z")).toBe("2 Jan 2026");
  });

  it("is null for text that is not a date", () => {
    expect(wishlistImportDate("yesterday")).toBeNull();
  });
});

describe("skippedWishlistMessage", () => {
  it("is null when every previewed game was imported", () => {
    expect(skippedWishlistMessage(5, 5)).toBeNull();
    expect(skippedWishlistMessage(0, 0)).toBeNull();
  });

  it("names the number of games that were left out", () => {
    expect(skippedWishlistMessage(5, 3)).toBe(
      "2 games could not be named by Steam right now and were left out - try the import again later",
    );
  });

  it("uses the singular for one game", () => {
    expect(skippedWishlistMessage(5, 4)).toBe(
      "1 game could not be named by Steam right now and was left out - try the import again later",
    );
  });
});
