import { describe, expect, it } from "vitest";
import { pathWithQuery } from "~/lib/pathWithQuery";

describe("pathWithQuery", () => {
  it("appends the query as an encoded search string", () => {
    expect(
      pathWithQuery("/creation-tool", { title: "Portal 2", custom: "1" }),
    ).toBe("/creation-tool?title=Portal+2&custom=1");
  });

  it("stringifies numbers and booleans", () => {
    expect(pathWithQuery("/x", { hours: 7.5, owned: true })).toBe(
      "/x?hours=7.5&owned=true",
    );
  });

  it("skips undefined and null values", () => {
    expect(pathWithQuery("/x", { a: undefined, b: null, c: "" })).toBe("/x?c=");
  });

  it("returns the bare path without any query", () => {
    expect(pathWithQuery("/x", {})).toBe("/x");
  });

  it("encodes reserved characters", () => {
    expect(pathWithQuery("/x", { q: "a&b=c#d" })).toBe("/x?q=a%26b%3Dc%23d");
  });
});
