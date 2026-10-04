import { describe, expect, it } from "vitest";
import { isHttpUrl } from "~/lib/safeUrl";

describe("isHttpUrl", () => {
  it("accepts http and https urls", () => {
    expect(isHttpUrl("https://www.cheapshark.com/redirect?dealID=abc")).toBe(
      true,
    );
    expect(isHttpUrl("http://example.com/game")).toBe(true);
  });

  it("rejects script and data urls that would run when clicked", () => {
    expect(isHttpUrl("javascript:alert(1)")).toBe(false);
    expect(isHttpUrl("data:text/html,<script>alert(1)</script>")).toBe(false);
    expect(isHttpUrl("vbscript:msgbox(1)")).toBe(false);
  });

  it("rejects relative, protocol-relative and malformed values", () => {
    expect(isHttpUrl("/redirect?dealID=abc")).toBe(false);
    expect(isHttpUrl("//example.com")).toBe(false);
    expect(isHttpUrl("not a url")).toBe(false);
    expect(isHttpUrl("")).toBe(false);
  });
});
