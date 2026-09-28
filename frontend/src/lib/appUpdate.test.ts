import { describe, expect, it } from "vitest";
import { downloadPercent } from "~/lib/appUpdate";

describe("downloadPercent", () => {
  it("returns the rounded share of the download that has finished", () => {
    expect(downloadPercent(0, 200)).toBe(0);
    expect(downloadPercent(50, 200)).toBe(25);
    expect(downloadPercent(1, 3)).toBe(33);
    expect(downloadPercent(200, 200)).toBe(100);
  });

  it("returns null while the total size is unknown", () => {
    expect(downloadPercent(50, undefined)).toBeNull();
    expect(downloadPercent(50, 0)).toBeNull();
  });

  it("never exceeds 100 when more bytes arrive than announced", () => {
    expect(downloadPercent(250, 200)).toBe(100);
  });
});
