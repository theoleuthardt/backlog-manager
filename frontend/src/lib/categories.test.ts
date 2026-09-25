import { describe, expect, it } from "vitest";
import {
  CATEGORY_COLORS,
  CATEGORY_NAME_MAX_LENGTH,
  categoryNameError,
  nextCategoryColor,
} from "~/lib/categories";
import { isHexColor } from "~/lib/themes";

describe("categoryNameError", () => {
  it("accepts a fresh, non-empty name", () => {
    expect(categoryNameError("Co-op", ["Story"])).toBe("");
  });

  it("stays silent for an empty name so the field is not flagged before typing", () => {
    expect(categoryNameError("   ", [])).toBe("");
  });

  it("rejects names that are too long", () => {
    expect(categoryNameError("x".repeat(CATEGORY_NAME_MAX_LENGTH + 1), [])).toMatch(
      /max/i,
    );
  });

  it("rejects duplicates case-insensitively after trimming", () => {
    expect(categoryNameError("  story ", ["Story"])).toMatch(/already/i);
  });
});

describe("nextCategoryColor", () => {
  it("only hands out valid hex colours", () => {
    expect(CATEGORY_COLORS.every(isHexColor)).toBe(true);
  });

  it("cycles through the palette by how many categories exist", () => {
    expect(nextCategoryColor(0)).toBe(CATEGORY_COLORS[0]);
    expect(nextCategoryColor(CATEGORY_COLORS.length)).toBe(CATEGORY_COLORS[0]);
    expect(nextCategoryColor(1)).toBe(CATEGORY_COLORS[1]);
  });
});
