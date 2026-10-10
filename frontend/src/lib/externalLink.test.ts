import { describe, expect, it, vi } from "vitest";
import { openExternalLink } from "~/lib/externalLink";

describe("openExternalLink", () => {
  it("hands http(s) urls to the opener", async () => {
    const open = vi.fn().mockResolvedValue(undefined);
    await openExternalLink(
      "https://steamdb.com/en/tools/steam-id-finder",
      open,
    );
    expect(open).toHaveBeenCalledWith(
      "https://steamdb.com/en/tools/steam-id-finder",
    );
  });

  it("never opens other schemes", async () => {
    const open = vi.fn().mockResolvedValue(undefined);
    await openExternalLink("javascript:alert(1)", open);
    await openExternalLink("file:///etc/passwd", open);
    await openExternalLink("/relative", open);
    expect(open).not.toHaveBeenCalled();
  });
});
