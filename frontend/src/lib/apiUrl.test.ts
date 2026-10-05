import { describe, expect, it } from "vitest";
import { parseApiUrl } from "~/lib/apiUrl";

describe("parseApiUrl", () => {
  it("defaults to the local backend in development", () => {
    expect(parseApiUrl(undefined, false)).toEqual({
      success: true,
      url: "http://localhost:8000",
    });
  });

  it("treats an empty value as unset", () => {
    expect(parseApiUrl("", false)).toEqual({
      success: true,
      url: "http://localhost:8000",
    });
  });

  it("requires the variable in production", () => {
    expect(parseApiUrl(undefined, true).success).toBe(false);
  });

  it("accepts https in production", () => {
    expect(parseApiUrl("https://api.example.com", true)).toEqual({
      success: true,
      url: "https://api.example.com",
    });
  });

  it("rejects plain http for a remote host in production", () => {
    const result = parseApiUrl("http://api.example.com", true);
    expect(result.success).toBe(false);
  });

  it.each([
    "http://localhost:8000",
    "http://127.0.0.1:8000",
    "http://[::1]:8000",
  ])("allows loopback %s over http in production", (url) => {
    expect(parseApiUrl(url, true).success).toBe(true);
  });

  it("rejects values that are not URLs", () => {
    expect(parseApiUrl("not a url", false).success).toBe(false);
  });
});
