import { describe, expect, it } from "vitest";
import {
  advanceStars,
  createStars,
  rescaleStars,
  starCountFor,
} from "~/lib/starfield";

describe("starCountFor", () => {
  it("keeps the density constant across screen sizes", () => {
    const small = starCountFor(800, 600);
    const large = starCountFor(3440, 1440);
    expect(large).toBeGreaterThan(small);
    expect(large / (3440 * 1440)).toBeCloseTo(small / (800 * 600), 4);
  });

  it("is bounded so a huge window cannot flood the canvas", () => {
    expect(starCountFor(7680, 4320)).toBeLessThanOrEqual(600);
    expect(starCountFor(0, 0)).toBe(0);
  });
});

describe("createStars", () => {
  it("places every star inside the given area", () => {
    const stars = createStars(300, 1200, 700, () => 0.999);
    expect(stars).toHaveLength(300);
    for (const star of stars) {
      expect(star.x).toBeLessThanOrEqual(1200);
      expect(star.y).toBeLessThanOrEqual(700);
    }
  });
});

describe("rescaleStars", () => {
  it("keeps the relative position when the area grows", () => {
    const [star] = rescaleStars(
      [{ x: 100, y: 50, size: 1, speed: 1 }],
      200,
      100,
      400,
      300,
    );
    expect(star).toMatchObject({ x: 200, y: 150 });
  });

  it("returns the same stars for an unmeasured previous area", () => {
    const stars = [{ x: 10, y: 10, size: 1, speed: 1 }];
    expect(rescaleStars(stars, 0, 0, 400, 300)).toEqual(stars);
  });
});

describe("advanceStars", () => {
  it("moves stars up and wraps them to the bottom edge", () => {
    const stars = [
      { x: 5, y: 0.5, size: 1, speed: 1 },
      { x: 6, y: 50, size: 1, speed: 2 },
    ];
    advanceStars(stars, 100);
    expect(stars[0]?.y).toBe(100);
    expect(stars[1]?.y).toBe(48);
  });
});
